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

  /// Attaches [studentId] to [pieceId], completing a pairing/invite
  /// acceptance. Idempotent if [studentId] is already the paired student;
  /// fails if the piece is already paired with a *different* student.
  ///
  /// Owned by callers in `feature_pairing` — this package only exposes the
  /// mutation itself, mirroring how `AnnotationRepository.replaceAuthorSlice`
  /// exposes a privileged operation for `review_sync` to drive without this
  /// package needing to know about sync or pairing semantics.
  Future<Result<Piece>> pairStudent(
    String pieceId, {
    required String studentId,
  });

  /// Registers a piece received for the first time via a cross-device
  /// transfer (e.g. `review_sync`'s "first share" bundle, which embeds the
  /// base PDF precisely so a receiver who has never seen this piece before
  /// can create it locally), preserving the sender's identity fields
  /// ([pieceId], [teacherId], [studentId]) rather than minting a fresh
  /// [Piece.id] the way [importPiece] does for a teacher's own local
  /// import — the receiver must end up tracking the exact same piece the
  /// sender does.
  ///
  /// [sourcePath] is a local (scratch) copy of the base PDF's bytes; this
  /// repository copies it into its own persistent storage and checksums it,
  /// mirroring [importPiece]. Fails if [pieceId] already exists locally —
  /// callers should check via [getPiece] first and only call this for a
  /// genuinely new piece.
  Future<Result<Piece>> registerImportedPiece({
    required String pieceId,
    required String title,
    required String teacherId,
    required String sourcePath,
    String? studentId,
  });
}
