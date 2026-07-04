import 'package:core_utils/core_utils.dart';
import 'package:pieces/src/domain/review_bundle.dart';

/// Contract for exporting a piece's annotations to a shareable bundle file,
/// handing that bundle off via the OS share sheet, and importing a bundle
/// shared by someone else back onto a local piece.
abstract class ReviewSyncService {
  /// Serializes [pieceId]'s current annotations (and referenced audio
  /// assets) into an [ExportedBundle] on disk.
  Future<Result<ExportedBundle>> exportBundle(String pieceId);

  /// Hands [bundle] off to the OS share sheet (or equivalent).
  Future<Result<void>> share(ExportedBundle bundle);

  /// Reads the bundle file at [filePath] and merges its annotations into
  /// the matching local piece.
  Future<Result<ReviewBundleSummary>> importBundle(String filePath);
}
