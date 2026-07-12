import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/data/firestore_annotation_mappers.dart';
import 'package:duet/domain/domain.dart';

/// An [AnnotationRepository] backed by Cloud Firestore — the cloud counterpart
/// to `LocalAnnotationRepository`. Ink lives in one document *per author*
/// (`/pieces/{id}/layers/{uid}`), so concurrent participants never write the
/// same document and live sync is conflict-free by construction; audio notes
/// are one document each (`/pieces/{id}/notes/{noteId}`).
///
/// [watch] combines three real-time streams — the layers collection, the notes
/// collection, and the piece document (participant identity) — into a
/// [PieceAnnotations]. It emits only once all three have loaded (so `.first`
/// reflects true current state rather than an empty race), then on every
/// change (combine-latest). Each layer's [PieceRole] is derived from the
/// piece's `ownerId`, and tombstoned notes (M4.4) are filtered out here.
///
/// **Ownership.** The client-side guards mirror `LocalAnnotationRepository`
/// verbatim (a participant may only mutate their own strokes/notes) as defense
/// in depth; the M2.2 security rules are the real backstop, and a rules-denied
/// write surfaces as an [OwnershipViolation] so bloc behaviour matches the
/// local repository's contract.
///
/// **Privileged ops.** [replaceAuthorSlice]/[removeAuthorSlice]/[clearPiece]
/// are not operations the rules grant a client across authors (own-layer writes
/// only; notes are never client-deleted). They run against Firestore here for
/// the fake-backed tests and the own-author case; in production the
/// cross-author cascades are the M3.8 purge Function's job, and `review_sync`
/// falls back to local-only annotations when importing another author's bundle
/// slice (see the annotation notes in `docs/duet_cloud_schema.md`).
///
/// Not wired into DI yet — M3.6 flips `useFirebase` onto this.
class FirestoreAnnotationRepository implements AnnotationRepository {
  /// Creates a [FirestoreAnnotationRepository].
  FirestoreAnnotationRepository({
    required FirebaseFirestore firestore,
    required String Function() currentUserId,
    DateTime Function()? clock,
  }) : _firestore = firestore,
       _currentUserId = currentUserId,
       _now = clock ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final String Function() _currentUserId;
  final DateTime Function() _now;

  CollectionReference<Map<String, dynamic>> get _pieces =>
      _firestore.collection('pieces');

  DocumentReference<Map<String, dynamic>> _pieceRef(String pieceId) =>
      _pieces.doc(pieceId);

  CollectionReference<Map<String, dynamic>> _layers(String pieceId) =>
      _pieceRef(pieceId).collection('layers');

  CollectionReference<Map<String, dynamic>> _notes(String pieceId) =>
      _pieceRef(pieceId).collection('notes');

  /// Runs [action], mapping a rules `permission-denied` to an
  /// [OwnershipViolation] so blocs see the same failure the local repository
  /// raises for an unauthorized mutation.
  Future<Result<T>> _guarded<T>(
    String resourceId,
    Future<T> Function() action,
  ) => Result.guard<T>(() async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw OwnershipViolation(resourceId, reason: e.message);
      }
      rethrow;
    }
  });

  @override
  Stream<PieceAnnotations> watch(String pieceId) {
    late final StreamController<PieceAnnotations> controller;
    final subscriptions = <StreamSubscription<void>>[];

    // The most recent snapshot of each source; a `null` layers/notes means "not
    // yet loaded", so the first emission waits for all three (combine-latest).
    List<InkLayer>? layers;
    List<AudioNote>? notes;
    var pieceLoaded = false;
    String? ownerId;

    void emit() {
      final currentLayers = layers;
      final currentNotes = notes;
      if (currentLayers == null || currentNotes == null || !pieceLoaded) {
        return;
      }
      final owner = ownerId;
      controller.add(
        PieceAnnotations(
          pieceId: pieceId,
          layers: <InkLayer>[
            for (final layer in currentLayers)
              InkLayer(
                ownerId: layer.ownerId,
                // The piece's owner is authoritative; every other author is a
                // collaborator. Fall back to the layer's stored role only when
                // the piece document is unseen (deleted / not yet created).
                role: owner == null
                    ? layer.role
                    : (layer.ownerId == owner
                          ? PieceRole.owner
                          : PieceRole.collaborator),
                strokes: layer.strokes,
              ),
          ],
          audioNotes: currentNotes,
        ),
      );
    }

    void start() {
      subscriptions.addAll(<StreamSubscription<void>>[
        _layers(pieceId).snapshots().listen((snapshot) {
          layers = snapshot.docs
              .map((doc) => layerFromFirestore(doc.id, doc.data()))
              .toList();
          emit();
        }),
        _notes(pieceId).snapshots().listen((snapshot) {
          notes = <AudioNote>[
            for (final doc in snapshot.docs)
              if (!isAudioNoteTombstoned(doc.data()))
                audioNoteFromFirestore(doc.id, doc.data()),
          ];
          emit();
        }),
        _pieceRef(pieceId).snapshots().listen((snapshot) {
          pieceLoaded = true;
          ownerId = snapshot.data()?['ownerId'] as String?;
          emit();
        }),
      ]);
    }

    Future<void> stop() async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      subscriptions.clear();
    }

    controller = StreamController<PieceAnnotations>.broadcast(
      onListen: start,
      onCancel: stop,
    );
    return controller.stream;
  }

  @override
  Future<Result<void>> addStroke(String pieceId, InkStroke stroke) =>
      _guarded<void>(stroke.id, () async {
        final authorId = stroke.authorId;
        if (authorId != _currentUserId()) {
          throw OwnershipViolation(
            stroke.id,
            reason: 'cannot add a stroke authored by another participant',
          );
        }
        final layerRef = _layers(pieceId).doc(authorId);
        await _firestore.runTransaction<void>((tx) async {
          final layerSnapshot = await tx.get(layerRef);
          if (layerSnapshot.exists) {
            final data = layerSnapshot.data()!;
            final existing = layerFromFirestore(authorId, data);
            tx.set(
              layerRef,
              layerToFirestore(
                existing.copyWith(strokes: [...existing.strokes, stroke]),
                rev: _nextRev(data),
                updatedAt: _now(),
              ),
            );
          } else {
            // First stroke: resolve the author's role from the piece (owner vs.
            // collaborator), read inside the transaction so the create is
            // consistent with membership at write time.
            final pieceSnapshot = await tx.get(_pieceRef(pieceId));
            tx.set(
              layerRef,
              layerToFirestore(
                InkLayer(
                  ownerId: authorId,
                  role: _roleFor(pieceSnapshot.data(), authorId),
                  strokes: [stroke],
                ),
                rev: 1,
                updatedAt: _now(),
              ),
            );
          }
        });
      });

  @override
  Future<Result<void>> eraseStroke(String pieceId, String strokeId) =>
      _guarded<void>(strokeId, () async {
        final uid = _currentUserId();
        // Locate the stroke across layers (participants may read all layers) to
        // reproduce the local repository's guards exactly: an unknown stroke is
        // a StateError, another author's stroke an OwnershipViolation. The
        // transaction then rewrites only the caller's own layer document.
        final layersSnapshot = await _layers(pieceId).get();
        String? holderId;
        for (final doc in layersSnapshot.docs) {
          final match = strokesFromLayer(
            doc.data(),
          ).where((s) => s.id == strokeId);
          if (match.isEmpty) continue;
          if (match.first.authorId != uid) {
            throw OwnershipViolation(strokeId, reason: 'not the stroke author');
          }
          holderId = doc.id;
          break;
        }
        if (holderId == null) {
          throw StateError('Unknown stroke: $strokeId');
        }
        final layerRef = _layers(pieceId).doc(holderId);
        await _firestore.runTransaction<void>((tx) async {
          final snapshot = await tx.get(layerRef);
          if (!snapshot.exists) return;
          final data = snapshot.data()!;
          final layer = layerFromFirestore(holderId!, data);
          tx.set(
            layerRef,
            layerToFirestore(
              layer.copyWith(
                strokes: layer.strokes.where((s) => s.id != strokeId).toList(),
              ),
              rev: _nextRev(data),
              updatedAt: _now(),
            ),
          );
        });
      });

  @override
  Future<Result<void>> addAudioNote(String pieceId, AudioNote note) =>
      _guarded<void>(note.id, () async {
        if (note.authorId != _currentUserId()) {
          throw OwnershipViolation(
            note.id,
            reason: 'cannot add an audio note authored by another participant',
          );
        }
        await _notes(pieceId).doc(note.id).set(audioNoteToFirestore(note));
      });

  @override
  Future<Result<void>> deleteAudioNote(String pieceId, String noteId) =>
      _guarded<void>(noteId, () async {
        final ref = _notes(pieceId).doc(noteId);
        final snapshot = await ref.get();
        final data = snapshot.data();
        if (data == null || isAudioNoteTombstoned(data)) {
          throw StateError('Unknown audio note: $noteId');
        }
        if (data['authorId'] != _currentUserId()) {
          throw OwnershipViolation(noteId, reason: 'not the note author');
        }
        // Plain delete for M3.2; M4.4 converts this to a `deletedAt` tombstone
        // update (the only note mutation the rules permit) so deletes converge
        // across offline peers instead of resurrecting.
        await ref.delete();
      });

  @override
  Future<Result<void>> clearPiece(String pieceId) =>
      _guarded<void>(pieceId, () async {
        // Privileged, non-gated: the caller has already checked it may delete
        // the piece. The full server-side cascade (Storage objects, reads) is
        // the M3.8 purge Function's job; here we drop the annotation documents.
        await _deleteAll(_layers(pieceId));
        await _deleteAll(_notes(pieceId));
      });

  @override
  Future<Result<void>> replaceAuthorSlice(
    String pieceId,
    String authorId, {
    required PieceRole role,
    required List<InkStroke> strokes,
    required List<AudioNote> audioNotes,
  }) => _guarded<void>(pieceId, () async {
    final layerRef = _layers(pieceId).doc(authorId);
    final previous = await layerRef.get();
    final existingNotes = await _notes(
      pieceId,
    ).where('authorId', isEqualTo: authorId).get();

    final batch = _firestore.batch()
      ..set(
        layerRef,
        layerToFirestore(
          InkLayer(ownerId: authorId, role: role, strokes: strokes),
          rev: _nextRev(previous.data()),
          updatedAt: _now(),
        ),
      );
    for (final doc in existingNotes.docs) {
      batch.delete(doc.reference);
    }
    for (final note in audioNotes) {
      batch.set(_notes(pieceId).doc(note.id), audioNoteToFirestore(note));
    }
    await batch.commit();
  });

  @override
  Future<Result<void>> removeAuthorSlice(String pieceId, String authorId) =>
      _guarded<void>(pieceId, () async {
        final existingNotes = await _notes(
          pieceId,
        ).where('authorId', isEqualTo: authorId).get();
        final batch = _firestore.batch()
          ..delete(_layers(pieceId).doc(authorId));
        for (final doc in existingNotes.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      });

  /// The author's [PieceRole] from the piece's `ownerId`: the owner is the
  /// owner, everyone else a collaborator (an unresolvable piece defaults to
  /// collaborator, matching `LocalAnnotationRepository._roleFor`).
  PieceRole _roleFor(Map<String, dynamic>? pieceData, String authorId) =>
      pieceData != null && pieceData['ownerId'] == authorId
      ? PieceRole.owner
      : PieceRole.collaborator;

  /// The next monotonic layer revision after the one in [data].
  int _nextRev(Map<String, dynamic>? data) => ((data?['rev'] as int?) ?? 0) + 1;

  Future<void> _deleteAll(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snapshot = await collection.get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
