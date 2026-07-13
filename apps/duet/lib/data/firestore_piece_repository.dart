import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/data/firestore_piece_mappers.dart';
import 'package:duet/domain/domain.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

/// A [PieceRepository] backed by Cloud Firestore (`/pieces`, per
/// `docs/duet_cloud_schema.md`) — the cloud counterpart to
/// `LocalPieceRepository`. Real-time reads are a `snapshots()` listener scoped
/// to the caller's own pieces (`participantIds array-contains`); mutations that
/// read-modify-write run in transactions so concurrent participants don't
/// clobber each other.
///
/// **Metadata only (M3.1).** The base PDF's *bytes* aren't in Firestore — the
/// doc carries only its `basePdfChecksum`. Until upload/download lands
/// (M3.3/M3.4) the binary stays device-local: [importPiece]/
/// [registerImportedPiece] stage it under the app's `pieces/` directory and
/// record the path in a local side-map, and reads hydrate `basePdfPath` from
/// that cache (empty for a piece synced from another device whose binary hasn't
/// downloaded yet — M3.4).
///
/// **Production write paths.** Under the M2.2 rules a client can't mutate
/// `participantIds`, so invite *acceptance* and *leave* go through the M2.4
/// callables, not [addCollaborator]/[leavePiece] here. Those methods remain for
/// the migration/import paths that legitimately self-mutate (M3.6) and for
/// tests; a rules-denied write is mapped to [OwnershipViolation] so bloc
/// behaviour matches the local repository's documented contract.
///
/// Bound under `useFirebase: true` (M3.6); the default composition keeps the
/// local repository.
class FirestorePieceRepository implements PieceRepository {
  /// Creates a [FirestorePieceRepository].
  FirestorePieceRepository({
    required FirebaseFirestore firestore,
    required String Function() currentUserId,
    required PdfRenderService pdfRenderService,
    required LocalStorageService storage,
    Future<Directory> Function()? documentsDirectory,
    DateTime Function()? clock,
  }) : _firestore = firestore,
       _currentUserId = currentUserId,
       _pdfRenderService = pdfRenderService,
       _storage = storage,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _now = clock ?? DateTime.now;

  /// Local side-map of `pieceId -> staged base-PDF path` (the device-local
  /// binary cache, replaced by real Storage download in M3.4).
  static const String _basePathsKey = 'pieces.cloudBasePaths';

  final FirebaseFirestore _firestore;
  final String Function() _currentUserId;
  final PdfRenderService _pdfRenderService;
  final LocalStorageService _storage;
  final Future<Directory> Function() _documentsDirectory;
  final DateTime Function() _now;

  CollectionReference<Map<String, dynamic>> get _pieces =>
      _firestore.collection('pieces');

  Map<String, String> _basePaths() {
    final raw = _storage.getString(_basePathsKey);
    if (raw == null) return <String, String>{};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    );
  }

  String _basePathFor(String pieceId) => _basePaths()[pieceId] ?? '';

  Future<void> _recordBasePath(String pieceId, String path) {
    final next = _basePaths()..[pieceId] = path;
    return _storage.setString(_basePathsKey, jsonEncode(next));
  }

  Future<void> _forgetBasePath(String pieceId) {
    final next = _basePaths()..remove(pieceId);
    return _storage.setString(_basePathsKey, jsonEncode(next));
  }

  /// Copies the PDF at [sourcePath] into the app's persistent `pieces/`
  /// directory keyed by [id] and checksums it — the local staging M3.3 will
  /// replace with a Storage upload (the checksum is still needed for the doc).
  Future<({String checksum, String destPath})> _stageLocally(
    String id,
    String sourcePath,
  ) async {
    final checksum = (await _pdfRenderService.checksum(sourcePath)).orThrow();
    final documentsDir = await _documentsDirectory();
    final piecesDir = Directory(p.join(documentsDir.path, 'pieces'))
      ..createSync(recursive: true);
    final destPath = p.join(piecesDir.path, '$id${p.extension(sourcePath)}');
    await File(sourcePath).copy(destPath);
    return (checksum: checksum, destPath: destPath);
  }

  Piece _pieceFrom(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Unknown piece: ${snapshot.id}');
    }
    return pieceFromFirestore(
      snapshot.id,
      data,
      basePdfPath: _basePathFor(snapshot.id),
    );
  }

  /// Runs [action], mapping a rules `permission-denied` to an
  /// [OwnershipViolation] so blocs see the same failure the local repository
  /// raises for an unauthorized mutation.
  Future<Result<T>> _guarded<T>(String pieceId, Future<T> Function() action) =>
      Result.guard<T>(() async {
        try {
          return await action();
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            throw OwnershipViolation(pieceId, reason: e.message);
          }
          rethrow;
        }
      });

  @override
  Stream<List<Piece>> watchPieces() {
    return _pieces
        .where('participantIds', arrayContains: _currentUserId())
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(_pieceFrom).toList(growable: false),
        );
  }

  @override
  Future<Result<Piece>> getPiece(String pieceId) =>
      _guarded<Piece>(pieceId, () async {
        final snapshot = await _pieces.doc(pieceId).get();
        if (!snapshot.exists) {
          throw StateError('Unknown piece: $pieceId');
        }
        return _pieceFrom(snapshot);
      });

  @override
  Stream<Map<String, DateTime>> watchReads() {
    // A collection-group query gathers the caller's own `reads/{uid}` docs
    // across every piece in one listener. The `uid` field (mirrored from the
    // doc id) is what the query filters on — the security rules gate a
    // collection-group read on `resource.data.uid == request.auth.uid`.
    return _firestore
        .collectionGroup('reads')
        .where('uid', isEqualTo: _currentUserId())
        .snapshots()
        .map((snapshot) {
          final reads = <String, DateTime>{};
          for (final doc in snapshot.docs) {
            final pieceRef = doc.reference.parent.parent;
            final lastOpenedAt = doc.data()['lastOpenedAt'];
            if (pieceRef != null && lastOpenedAt is Timestamp) {
              reads[pieceRef.id] = lastOpenedAt.toDate();
            }
          }
          return reads;
        });
  }

  @override
  Future<Result<void>> markOpened(String pieceId) =>
      _guarded<void>(pieceId, () async {
        final uid = _currentUserId();
        await _pieces.doc(pieceId).collection('reads').doc(uid).set(
          <String, dynamic>{
            'uid': uid,
            'lastOpenedAt': Timestamp.fromDate(_now()),
          },
          SetOptions(merge: true),
        );
      });

  @override
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
    String? ownerName,
  }) => _guarded<Piece>('', () async {
    final ref = _pieces.doc();
    final staged = await _stageLocally(ref.id, sourcePath);
    await _recordBasePath(ref.id, staged.destPath);

    final now = _now();
    final piece = Piece(
      id: ref.id,
      title: title,
      basePdfChecksum: staged.checksum,
      basePdfPath: staged.destPath,
      ownerId: _currentUserId(),
      ownerName: ownerName,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(pieceToFirestore(piece));
    return piece;
  });

  @override
  Future<Result<Piece>> registerImportedPiece({
    required String pieceId,
    required String title,
    required String ownerId,
    required String sourcePath,
    String? collaboratorId,
    String? ownerName,
    String? collaboratorName,
  }) => _guarded<Piece>(pieceId, () async {
    final ref = _pieces.doc(pieceId);
    if ((await ref.get()).exists) {
      throw StateError('Piece already exists: $pieceId');
    }
    final staged = await _stageLocally(pieceId, sourcePath);
    await _recordBasePath(pieceId, staged.destPath);

    final now = _now();
    final piece = Piece(
      id: pieceId,
      title: title,
      basePdfChecksum: staged.checksum,
      basePdfPath: staged.destPath,
      ownerId: ownerId,
      ownerName: ownerName,
      collaborators: collaboratorId == null
          ? null
          : [Collaborator(uid: collaboratorId, name: collaboratorName)],
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(pieceToFirestore(piece));
    return piece;
  });

  @override
  Future<Result<void>> renamePiece(String pieceId, String title) =>
      _guarded<void>(pieceId, () async {
        await _mutate(pieceId, (piece) => piece.copyWith(title: title));
      });

  @override
  Future<Result<void>> deletePiece(String pieceId) =>
      _guarded<void>(pieceId, () async {
        final ref = _pieces.doc(pieceId);
        await _firestore.runTransaction<void>((tx) async {
          final snapshot = await tx.get(ref);
          final piece = _pieceFrom(snapshot);
          if (_currentUserId() != piece.ownerId) {
            throw OwnershipViolation(
              pieceId,
              reason: 'only the owner may delete a piece',
            );
          }
          tx.delete(ref);
        });
        // M3.8 extends: cascade the piece's layers/notes/reads + Storage
        // objects (the local repo purges annotations here; the cloud cascade
        // is a Function).
        await _forgetBasePath(pieceId);
      });

  @override
  Future<Result<void>> leavePiece(String pieceId) =>
      _guarded<void>(pieceId, () async {
        // Production routes leave through the M2.4 `leavePiece` callable (the
        // rules make `participantIds` immutable to clients); this direct path
        // serves the migration/tests.
        final userId = _currentUserId();
        await _mutate(pieceId, (piece) {
          if (userId == piece.ownerId) {
            throw StateError(
              'The owner of this piece cannot leave it; delete it instead.',
            );
          }
          if (!piece.isCollaborator(userId)) return null; // No-op.
          return piece.copyWith(
            collaborators: piece.collaborators
                .where((c) => c.uid != userId)
                .toList(),
          );
        });
      });

  @override
  Future<Result<void>> addCollaborator(
    String pieceId, {
    required String userId,
    String? name,
    String? email,
  }) => _guarded<void>(pieceId, () async {
    await _mutate(pieceId, (piece) {
      final existing = piece.collaborators.where((c) => c.uid == userId);
      final Collaborator resolved;
      if (existing.isEmpty) {
        resolved = Collaborator(uid: userId, name: name, email: email);
      } else {
        // Idempotent: only ever fill in a newly-given name/email.
        resolved = Collaborator(
          uid: userId,
          name: name ?? existing.first.name,
          email: email ?? existing.first.email,
        );
        if (resolved == existing.first) return null; // Fully no-op.
      }
      return piece.copyWith(
        collaborators: [
          for (final c in piece.collaborators)
            if (c.uid == userId) resolved else c,
          if (existing.isEmpty) resolved,
        ],
      );
    });
  });

  @override
  Future<Result<void>> removeCollaborator(String pieceId, String userId) =>
      _guarded<void>(pieceId, () async {
        await _mutate(pieceId, (piece) {
          if (_currentUserId() != piece.ownerId) {
            throw OwnershipViolation(
              pieceId,
              reason: 'only the owner may remove a collaborator',
            );
          }
          if (!piece.isCollaborator(userId)) return null; // No-op.
          return piece.copyWith(
            collaborators: piece.collaborators
                .where((c) => c.uid != userId)
                .toList(),
          );
        });
        // M3.8 extends: drop the removed collaborator's layer/notes (the local
        // repo calls AnnotationRepository.removeAuthorSlice here).
      });

  @override
  Future<Result<Piece>> pairCollaborator(
    String pieceId, {
    required String collaboratorId,
    String? collaboratorName,
    String? collaboratorEmail,
    String? ownerName,
  }) => _guarded<Piece>(pieceId, () async {
    await _mutate(pieceId, (piece) {
      // `ownerName` is a backfill — only fills a piece without one, never
      // clobbers an existing one.
      final resolvedOwnerName = piece.ownerName ?? ownerName;
      final withOwner = resolvedOwnerName == piece.ownerName
          ? piece
          : piece.copyWith(ownerName: resolvedOwnerName);

      final existing = withOwner.collaborators.where(
        (c) => c.uid == collaboratorId,
      );
      final Collaborator resolved;
      if (existing.isEmpty) {
        resolved = Collaborator(
          uid: collaboratorId,
          name: collaboratorName,
          email: collaboratorEmail,
        );
      } else {
        resolved = Collaborator(
          uid: collaboratorId,
          name: collaboratorName ?? existing.first.name,
          email: collaboratorEmail ?? existing.first.email,
        );
      }
      return withOwner.copyWith(
        collaborators: [
          for (final c in withOwner.collaborators)
            if (c.uid == collaboratorId) resolved else c,
          if (existing.isEmpty) resolved,
        ],
      );
    });
    final refreshed = await _pieces.doc(pieceId).get();
    return _pieceFrom(refreshed);
  });

  /// Read-modify-write a piece in a transaction. [change] returns the mutated
  /// piece (its `updatedAt` is bumped) or `null` for a no-op. Throws
  /// `StateError` when the piece is unknown.
  Future<void> _mutate(
    String pieceId,
    Piece? Function(Piece piece) change,
  ) async {
    final ref = _pieces.doc(pieceId);
    await _firestore.runTransaction<void>((tx) async {
      final snapshot = await tx.get(ref);
      final piece = _pieceFrom(snapshot);
      final changed = change(piece);
      if (changed == null) return;
      tx.set(ref, pieceToFirestore(changed.copyWith(updatedAt: _now())));
    });
  }
}
