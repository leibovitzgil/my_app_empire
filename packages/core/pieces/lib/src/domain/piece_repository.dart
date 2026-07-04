import 'package:core_utils/core_utils.dart';
import 'package:pieces/src/domain/piece.dart';

/// Contract for listing, importing and managing [Piece]s.
abstract class PieceRepository {
  /// Emits the current user's pieces (as teacher or student), updating as
  /// they change.
  Stream<List<Piece>> watchPieces();

  /// Fetches a single piece by [pieceId].
  Future<Result<Piece>> getPiece(String pieceId);

  /// Imports a new piece titled [title] from the PDF at [sourcePath].
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
  });

  /// Renames [pieceId] to [title].
  Future<Result<void>> renamePiece(String pieceId, String title);

  /// Permanently deletes [pieceId]. Owner (teacher) only.
  Future<Result<void>> deletePiece(String pieceId);

  /// Removes the current user's association with [pieceId] without
  /// deleting it for the other participant.
  Future<Result<void>> leavePiece(String pieceId);
}
