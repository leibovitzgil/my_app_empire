import 'package:core_utils/core_utils.dart';

/// Contract for storing and retrieving recorded audio-note assets
/// on-device.
abstract class AudioAssetStore {
  /// Copies the audio file at [sourcePath] into managed storage, returning
  /// the id it was stored under.
  Future<Result<String>> put(String sourcePath);

  /// Resolves the on-disk path for a previously stored [assetId].
  Future<Result<String>> pathFor(String assetId);

  /// Removes the stored asset for [assetId].
  Future<Result<void>> delete(String assetId);
}
