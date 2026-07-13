import 'dart:async';
import 'dart:convert';

import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:local_storage/local_storage.dart';

/// Supplies every locally-stored piece to a [LocalPieceMigrator]. Backed in
/// production by `LocalPieceRepository.storedPieces`; a plain list in tests.
typedef LocalPieceReader = Future<List<Piece>> Function();

/// The outcome of a [LocalPieceMigrator.migrate] pass: how many local pieces
/// were uploaded to the cloud and how many failed (and will be retried next
/// time).
class MigrationResult extends Equatable {
  /// Creates a [MigrationResult].
  const MigrationResult({required this.migrated, required this.failed});

  /// The number of pieces newly migrated to the cloud in this pass.
  final int migrated;

  /// The number of pieces that failed to migrate (left for a later retry).
  final int failed;

  @override
  List<Object?> get props => <Object?>[migrated, failed];
}

/// A one-time migration that uploads a device's locally-stored pieces (created
/// while the app ran against the in-memory/mock backend) into the signed-in
/// user's cloud account — the first time they sign in with `useFirebase: true`
/// (M3.6). Reads flow through the local repositories; writes through the cloud
/// (Firestore + Storage) ones, so the whole thing is fake-testable.
///
/// **Re-owned to the current user.** Each migrated piece is created with the
/// signed-in uid as its owner and its local collaborators (mock uids that
/// don't exist in the cloud) dropped; the owner's own ink layer and audio
/// notes are re-attributed to the current uid and written as a single owner
/// slice. Ink/notes authored by other (mock) participants are not migrated —
/// the common case is a single-user device migrating its own imported sheets.
///
/// **Resumable.** Every fully-migrated piece id is recorded per-uid in
/// `local_storage`; a piece whose upload fails midway is left unmarked and
/// retried on the next pass. A retry converges because the piece-doc create
/// tolerates a doc left behind (an existing doc is reused), the PDF upload
/// dedupes by checksum, and the slice write is a full replace. Local data is
/// kept as a read-through cache — never deleted.
class LocalPieceMigrator {
  /// Creates a [LocalPieceMigrator].
  LocalPieceMigrator({
    required LocalPieceReader readLocalPieces,
    required AnnotationRepository localAnnotations,
    required AudioAssetStore localAudio,
    required PieceRepository cloudPieces,
    required AnnotationRepository cloudAnnotations,
    required AudioAssetStore cloudAudio,
    required PieceBinaryStore binaryStore,
    required LocalStorageService storage,
    required String Function() currentUserId,
  }) : _readLocalPieces = readLocalPieces,
       _localAnnotations = localAnnotations,
       _localAudio = localAudio,
       _cloudPieces = cloudPieces,
       _cloudAnnotations = cloudAnnotations,
       _cloudAudio = cloudAudio,
       _binaryStore = binaryStore,
       _storage = storage,
       _currentUserId = currentUserId;

  static const String _migratedKeyPrefix = 'migration.pieces.migrated.';

  final LocalPieceReader _readLocalPieces;
  final AnnotationRepository _localAnnotations;
  final AudioAssetStore _localAudio;
  final PieceRepository _cloudPieces;
  final AnnotationRepository _cloudAnnotations;
  final AudioAssetStore _cloudAudio;
  final PieceBinaryStore _binaryStore;
  final LocalStorageService _storage;
  final String Function() _currentUserId;

  String get _migratedKey => '$_migratedKeyPrefix${_currentUserId()}';

  Set<String> _migratedIds() {
    final raw = _storage.getString(_migratedKey);
    if (raw == null) return <String>{};
    return (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
  }

  Future<void> _markMigrated(String pieceId) {
    final next = _migratedIds()..add(pieceId);
    return _storage.setString(_migratedKey, jsonEncode(next.toList()));
  }

  /// The number of locally-stored pieces not yet migrated for the current uid.
  Future<int> pendingCount() async {
    final migrated = _migratedIds();
    final pieces = await _readLocalPieces();
    return pieces.where((piece) => !migrated.contains(piece.id)).length;
  }

  /// Migrates every not-yet-migrated local piece to the cloud. Safe to call
  /// repeatedly: already-migrated pieces are skipped and a failed piece is
  /// retried on the next call.
  Future<MigrationResult> migrate() async {
    final migrated = _migratedIds();
    final pieces = await _readLocalPieces();
    var migratedCount = 0;
    var failedCount = 0;
    for (final piece in pieces) {
      if (migrated.contains(piece.id)) continue;
      if ((await _migrateOne(piece)) is Success<void>) {
        await _markMigrated(piece.id);
        migratedCount++;
      } else {
        failedCount++;
      }
    }
    return MigrationResult(migrated: migratedCount, failed: failedCount);
  }

  Future<Result<void>> _migrateOne(Piece local) => Result.guard<void>(() async {
    final uid = _currentUserId();

    // Create the cloud piece doc first — Storage/notes writes resolve
    // membership from it. A doc left by a prior failed pass is reused.
    if ((await _cloudPieces.getPiece(local.id)) is! Success<Piece>) {
      (await _cloudPieces.registerImportedPiece(
        pieceId: local.id,
        title: local.title,
        ownerId: uid,
        sourcePath: local.basePdfPath,
        ownerName: local.ownerName,
      )).orThrow();
    }

    // Upload the base PDF (dedupes by checksum, so a retry is a no-op).
    await _uploadBasePdf(local);

    // Re-attribute the owner's own slice to the current uid: collapse their
    // ink layer and migrate their audio notes (each note's asset is uploaded
    // afresh and its id re-keyed).
    final annotations = await _localAnnotations.watch(local.id).first;
    final strokes = <InkStroke>[
      for (final layer in annotations.layers)
        if (layer.ownerId == local.ownerId)
          for (final stroke in layer.strokes)
            InkStroke(
              id: stroke.id,
              authorId: uid,
              pageIndex: stroke.pageIndex,
              colorId: stroke.colorId,
              points: stroke.points,
            ),
    ];
    final notes = <AudioNote>[];
    for (final note in annotations.audioNotes) {
      if (note.authorId != local.ownerId) continue;
      final sourcePath = (await _localAudio.pathFor(
        note.audioAssetId,
        pieceId: local.id,
      )).orThrow();
      final assetId = (await _cloudAudio.put(
        sourcePath,
        pieceId: local.id,
      )).orThrow();
      notes.add(
        AudioNote(
          id: note.id,
          authorId: uid,
          audioAssetId: assetId,
          pageIndex: note.pageIndex,
          durationMs: note.durationMs,
          region: note.region,
          createdAt: note.createdAt,
        ),
      );
    }

    if (strokes.isNotEmpty || notes.isNotEmpty) {
      (await _cloudAnnotations.replaceAuthorSlice(
        local.id,
        uid,
        role: PieceRole.owner,
        strokes: strokes,
        audioNotes: notes,
      )).orThrow();
    }
  });

  Future<void> _uploadBasePdf(Piece local) async {
    // Drain the progress stream to completion; any upload error propagates out
    // of the stream and is caught by the enclosing `Result.guard`.
    await _binaryStore
        .uploadBasePdf(
          pieceId: local.id,
          localPath: local.basePdfPath,
          checksum: local.basePdfChecksum,
        )
        .drain<void>();
  }
}
