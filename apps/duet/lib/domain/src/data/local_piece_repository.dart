import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/src/data/piece_mappers.dart';
import 'package:duet/domain/src/domain/annotation_repository.dart';
import 'package:duet/domain/src/domain/audio_asset_store.dart';
import 'package:duet/domain/src/domain/collaborator.dart';
import 'package:duet/domain/src/domain/ownership.dart';
import 'package:duet/domain/src/domain/piece.dart';
import 'package:duet/domain/src/domain/piece_repository.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

/// A [PieceRepository] backed by [LocalStorageService] (JSON-encoded), with
/// imported PDFs copied into a persistent on-device `pieces/` directory
/// (resolved via `path_provider` by default; injectable for tests).
class LocalPieceRepository implements PieceRepository {
  /// Creates a [LocalPieceRepository].
  ///
  /// [annotationRepository] and [audioAssetStore] are used by [deletePiece]
  /// to purge a deleted piece's annotations and audio assets alongside its
  /// record. [annotationRepository] is a provider (rather than a plain
  /// instance) because the canonical `LocalAnnotationRepository` itself
  /// depends on a `PieceRepository` to resolve roles — resolving that
  /// dependency lazily, on first use, breaks the constructor cycle between
  /// the two repositories. [documentsDirectory] defaults to
  /// `getApplicationDocumentsDirectory`; override in tests with a temp dir.
  LocalPieceRepository({
    required LocalStorageService storage,
    required String Function() currentUserId,
    required PdfRenderService pdfRenderService,
    required AnnotationRepository Function() annotationRepository,
    required AudioAssetStore audioAssetStore,
    Future<Directory> Function()? documentsDirectory,
    DateTime Function()? clock,
  }) : _storage = storage,
       _currentUserId = currentUserId,
       _pdfRenderService = pdfRenderService,
       _annotationRepository = annotationRepository,
       _audioAssetStore = audioAssetStore,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _now = clock ?? DateTime.now {
    _pieces = _load();
  }

  static const String _storageKey = 'pieces.records';

  /// Per-user "last opened" watermarks, keyed `pieces.reads.<uid>` → a JSON
  /// `{pieceId: millisSinceEpoch}` map (M3.7). Per-uid so switching accounts
  /// on one device keeps each user's unread state separate.
  static const String _readsKeyPrefix = 'pieces.reads.';

  final LocalStorageService _storage;
  final String Function() _currentUserId;
  final PdfRenderService _pdfRenderService;
  final AnnotationRepository Function() _annotationRepository;
  final AudioAssetStore _audioAssetStore;
  final Future<Directory> Function() _documentsDirectory;
  final DateTime Function() _now;
  final StreamController<List<Piece>> _controller =
      StreamController<List<Piece>>.broadcast();
  final StreamController<Map<String, DateTime>> _readsController =
      StreamController<Map<String, DateTime>>.broadcast();

  late List<Piece> _pieces;
  int _seq = 0;

  List<Piece> _load() {
    final raw = _storage.getString(_storageKey);
    if (raw == null) return <Piece>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => pieceFromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _persist() => _storage.setString(
    _storageKey,
    jsonEncode(_pieces.map(pieceToJson).toList()),
  );

  List<Piece> _visibleTo(String userId) =>
      _pieces.where((piece) => piece.isParticipant(userId)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> _emit() async {
    await _persist();
    if (!_controller.isClosed) {
      _controller.add(_visibleTo(_currentUserId()));
    }
  }

  Piece? _findOrNull(String pieceId) {
    for (final piece in _pieces) {
      if (piece.id == pieceId) return piece;
    }
    return null;
  }

  Piece _require(String pieceId) {
    final piece = _findOrNull(pieceId);
    if (piece == null) {
      throw StateError('Unknown piece: $pieceId');
    }
    return piece;
  }

  void _replace(Piece updated) {
    _pieces = [
      for (final piece in _pieces)
        if (piece.id == updated.id) updated else piece,
    ];
  }

  String _nextId() => 'piece_${_now().microsecondsSinceEpoch}_${_seq++}';

  /// Copies the PDF at [sourcePath] into this repository's persistent
  /// `pieces/` directory under a name keyed by [id], and checksums it.
  /// Shared by [importPiece] (which mints [id] itself) and
  /// [registerImportedPiece] (which is handed [id] by the caller, to
  /// preserve a sender's piece identity).
  Future<({String checksum, String destPath})> _copyIntoPiecesStorage(
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

  @override
  Stream<List<Piece>> watchPieces() async* {
    yield _visibleTo(_currentUserId());
    yield* _controller.stream;
  }

  /// Every locally-stored piece, regardless of the current participant.
  ///
  /// [watchPieces] scopes to the signed-in user, but the one-time cloud
  /// migration (M3.6) runs as the *real* cloud uid while the stored pieces are
  /// owned by the prior mock identity — it needs them all. This is a concrete
  /// accessor (not on the [PieceRepository] contract), used only by the
  /// migrator.
  List<Piece> get storedPieces => List<Piece>.unmodifiable(_pieces);

  @override
  Future<Result<Piece>> getPiece(String pieceId) async {
    final piece = _findOrNull(pieceId);
    if (piece == null) {
      return ResultFailure<Piece>(StateError('Unknown piece: $pieceId'));
    }
    return Success(piece);
  }

  String get _readsKey => '$_readsKeyPrefix${_currentUserId()}';

  Map<String, DateTime> _loadReads() {
    final raw = _storage.getString(_readsKey);
    if (raw == null) return <String, DateTime>{};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (pieceId, millis) => MapEntry(
        pieceId,
        DateTime.fromMillisecondsSinceEpoch(millis as int),
      ),
    );
  }

  @override
  Stream<Map<String, DateTime>> watchReads() async* {
    yield _loadReads();
    yield* _readsController.stream;
  }

  @override
  Future<Result<void>> markOpened(String pieceId) =>
      Result.guard<void>(() async {
        final reads = _loadReads()..[pieceId] = _now();
        await _storage.setString(
          _readsKey,
          jsonEncode(
            reads.map(
              (id, at) => MapEntry(id, at.millisecondsSinceEpoch),
            ),
          ),
        );
        if (!_readsController.isClosed) _readsController.add(reads);
      });

  @override
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
    String? ownerName,
  }) => Result.guard<Piece>(() async {
    final id = _nextId();
    final copied = await _copyIntoPiecesStorage(id, sourcePath);

    final now = _now();
    final piece = Piece(
      id: id,
      title: title,
      basePdfChecksum: copied.checksum,
      basePdfPath: copied.destPath,
      ownerId: _currentUserId(),
      ownerName: ownerName,
      createdAt: now,
      updatedAt: now,
    );
    _pieces = [..._pieces, piece];
    await _emit();
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
  }) => Result.guard<Piece>(() async {
    if (_findOrNull(pieceId) != null) {
      throw StateError('Piece already exists locally: $pieceId');
    }
    final copied = await _copyIntoPiecesStorage(pieceId, sourcePath);

    final now = _now();
    final piece = Piece(
      id: pieceId,
      title: title,
      basePdfChecksum: copied.checksum,
      basePdfPath: copied.destPath,
      ownerId: ownerId,
      ownerName: ownerName,
      collaborators: collaboratorId == null
          ? null
          : [Collaborator(uid: collaboratorId, name: collaboratorName)],
      createdAt: now,
      updatedAt: now,
    );
    _pieces = [..._pieces, piece];
    await _emit();
    return piece;
  });

  @override
  Future<Result<void>> renamePiece(String pieceId, String title) =>
      Result.guard<void>(() async {
        final piece = _require(pieceId);
        _replace(piece.copyWith(title: title, updatedAt: _now()));
        await _emit();
      });

  @override
  Future<Result<void>> deletePiece(String pieceId) =>
      Result.guard<void>(() async {
        final piece = _require(pieceId);
        if (_currentUserId() != piece.ownerId) {
          throw OwnershipViolation(
            pieceId,
            reason: 'only the owner may delete a piece',
          );
        }

        final annotationRepository = _annotationRepository();
        final annotations = await annotationRepository.watch(pieceId).first;
        for (final note in annotations.audioNotes) {
          await _audioAssetStore.delete(note.audioAssetId, pieceId: pieceId);
        }
        (await annotationRepository.clearPiece(pieceId)).orThrow();

        _pieces = _pieces.where((piece) => piece.id != pieceId).toList();
        await _emit();
      });

  @override
  Future<Result<void>> leavePiece(String pieceId) => Result.guard<void>(
    () async {
      final piece = _require(pieceId);
      final userId = _currentUserId();
      if (userId == piece.ownerId) {
        throw StateError(
          'The owner of this piece cannot leave it; delete it instead.',
        );
      }
      if (!piece.isCollaborator(userId)) {
        // Already not associated; leaving is a no-op.
        return;
      }
      _replace(
        piece.copyWith(
          collaborators: piece.collaborators
              .where((collaborator) => collaborator.uid != userId)
              .toList(),
          updatedAt: _now(),
        ),
      );
      await _emit();
      (await _annotationRepository().removeAuthorSlice(
        pieceId,
        userId,
      )).orThrow();
    },
  );

  @override
  Future<Result<void>> addCollaborator(
    String pieceId, {
    required String userId,
    String? name,
    String? email,
  }) => Result.guard<void>(() async {
    final piece = _require(pieceId);
    final existing = piece.collaborators.where((c) => c.uid == userId);
    final Collaborator resolved;
    if (existing.isEmpty) {
      resolved = Collaborator(uid: userId, name: name, email: email);
    } else {
      // Idempotent re-invite/re-add: only ever *fills in* a newly-given
      // name/email, never clobbers an existing one with a null.
      resolved = Collaborator(
        uid: userId,
        name: name ?? existing.first.name,
        email: email ?? existing.first.email,
      );
      if (resolved == existing.first) return; // Fully no-op.
    }
    _replace(
      piece.copyWith(
        collaborators: [
          for (final c in piece.collaborators)
            if (c.uid == userId) resolved else c,
          if (existing.isEmpty) resolved,
        ],
        updatedAt: _now(),
      ),
    );
    await _emit();
  });

  @override
  Future<Result<void>> removeCollaborator(String pieceId, String userId) =>
      Result.guard<void>(() async {
        final piece = _require(pieceId);
        if (_currentUserId() != piece.ownerId) {
          throw OwnershipViolation(
            pieceId,
            reason: 'only the owner may remove a collaborator',
          );
        }
        if (!piece.isCollaborator(userId)) {
          return; // Already not a collaborator; removing is a no-op.
        }
        _replace(
          piece.copyWith(
            collaborators: piece.collaborators
                .where((collaborator) => collaborator.uid != userId)
                .toList(),
            updatedAt: _now(),
          ),
        );
        await _emit();
        (await _annotationRepository().removeAuthorSlice(
          pieceId,
          userId,
        )).orThrow();
      });

  @override
  Future<Result<Piece>> pairCollaborator(
    String pieceId, {
    required String collaboratorId,
    String? collaboratorName,
    String? collaboratorEmail,
    String? ownerName,
  }) => Result.guard<Piece>(() async {
    final piece = _require(pieceId);
    // `ownerName` is a *backfill*: it only ever fills in a piece that
    // doesn't already have one (e.g. one imported before this field
    // existed) — an existing `Piece.ownerName` (set by `importPiece`) is
    // never clobbered here, regardless of what's passed.
    final resolvedOwnerName = piece.ownerName ?? ownerName;
    if (resolvedOwnerName != piece.ownerName) {
      _replace(piece.copyWith(ownerName: resolvedOwnerName));
    }
    (await addCollaborator(
      pieceId,
      userId: collaboratorId,
      name: collaboratorName,
      email: collaboratorEmail,
    )).orThrow();
    return _require(pieceId);
  });
}
