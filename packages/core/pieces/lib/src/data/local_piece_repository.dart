import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/src/data/piece_mappers.dart';
import 'package:pieces/src/domain/annotation_repository.dart';
import 'package:pieces/src/domain/audio_asset_store.dart';
import 'package:pieces/src/domain/piece.dart';
import 'package:pieces/src/domain/piece_repository.dart';

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

  final LocalStorageService _storage;
  final String Function() _currentUserId;
  final PdfRenderService _pdfRenderService;
  final AnnotationRepository Function() _annotationRepository;
  final AudioAssetStore _audioAssetStore;
  final Future<Directory> Function() _documentsDirectory;
  final DateTime Function() _now;
  final StreamController<List<Piece>> _controller =
      StreamController<List<Piece>>.broadcast();

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

  List<Piece> _visibleTo(String userId) => _pieces
      .where((piece) => piece.teacherId == userId || piece.studentId == userId)
      .toList();

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

  @override
  Stream<List<Piece>> watchPieces() async* {
    yield _visibleTo(_currentUserId());
    yield* _controller.stream;
  }

  @override
  Future<Result<Piece>> getPiece(String pieceId) async {
    final piece = _findOrNull(pieceId);
    if (piece == null) {
      return ResultFailure<Piece>(StateError('Unknown piece: $pieceId'));
    }
    return Success(piece);
  }

  @override
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
  }) => Result.guard<Piece>(() async {
    final checksum = (await _pdfRenderService.checksum(sourcePath)).orThrow();

    final documentsDir = await _documentsDirectory();
    final piecesDir = Directory(p.join(documentsDir.path, 'pieces'))
      ..createSync(recursive: true);
    final id = _nextId();
    final destPath = p.join(piecesDir.path, '$id${p.extension(sourcePath)}');
    await File(sourcePath).copy(destPath);

    final now = _now();
    final piece = Piece(
      id: id,
      title: title,
      basePdfChecksum: checksum,
      basePdfPath: destPath,
      teacherId: _currentUserId(),
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
        _require(pieceId); // Throws if unknown.

        final annotationRepository = _annotationRepository();
        final annotations = await annotationRepository.watch(pieceId).first;
        for (final note in annotations.audioNotes) {
          await _audioAssetStore.delete(note.audioAssetId);
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
      if (userId == piece.teacherId) {
        throw StateError(
          'The teacher owns this piece and cannot leave it; delete it instead.',
        );
      }
      if (piece.studentId != userId) {
        // Already not associated; leaving is a no-op.
        return;
      }
      _replace(_withoutStudent(piece));
      await _emit();
    },
  );

  // `Piece.copyWith` can't clear `studentId` back to null (it treats a null
  // argument as "keep the existing value"), so leaving requires rebuilding
  // the record directly rather than going through `copyWith`.
  Piece _withoutStudent(Piece piece) => Piece(
    id: piece.id,
    title: piece.title,
    basePdfChecksum: piece.basePdfChecksum,
    basePdfPath: piece.basePdfPath,
    teacherId: piece.teacherId,
    createdAt: piece.createdAt,
    updatedAt: _now(),
  );
}
