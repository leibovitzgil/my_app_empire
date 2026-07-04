import 'package:core_utils/core_utils.dart';
import 'package:pieces/src/domain/piece.dart';
import 'package:pieces/src/domain/piece_repository.dart';

/// A [PieceRepository] stub. Real persistence (e.g. Firestore or on-device
/// storage) lands in a later phase; this keeps the package compiling
/// end-to-end against the contract in the meantime.
class LocalPieceRepository implements PieceRepository {
  @override
  Stream<List<Piece>> watchPieces() => throw UnimplementedError();

  @override
  Future<Result<Piece>> getPiece(String pieceId) => throw UnimplementedError();

  @override
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> renamePiece(String pieceId, String title) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> deletePiece(String pieceId) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> leavePiece(String pieceId) => throw UnimplementedError();
}
