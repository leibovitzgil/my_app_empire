import 'package:core_utils/core_utils.dart';
import 'package:pieces/pieces.dart';

/// A [ReviewSyncService] that packages a piece's annotations into a bundle
/// file, hands it off via `package:share_plus`'s OS share sheet, and reads
/// bundles picked with `package:file_picker` back in. Real bundling/sharing
/// lands in a later phase; this keeps the package compiling end-to-end
/// against the contract in the meantime.
class FileShareReviewSyncService implements ReviewSyncService {
  @override
  Future<Result<ExportedBundle>> exportBundle(String pieceId) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> share(ExportedBundle bundle) =>
      throw UnimplementedError();

  @override
  Future<Result<ReviewBundleSummary>> importBundle(String filePath) =>
      throw UnimplementedError();
}
