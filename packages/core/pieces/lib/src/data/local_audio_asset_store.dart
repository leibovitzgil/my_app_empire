import 'package:core_utils/core_utils.dart';
import 'package:pieces/src/domain/audio_asset_store.dart';

/// An [AudioAssetStore] stub. Real on-device file management lands in a
/// later phase; this keeps the package compiling end-to-end against the
/// contract in the meantime.
class LocalAudioAssetStore implements AudioAssetStore {
  @override
  Future<Result<String>> put(String sourcePath) => throw UnimplementedError();

  @override
  Future<Result<String>> pathFor(String assetId) => throw UnimplementedError();

  @override
  Future<Result<void>> delete(String assetId) => throw UnimplementedError();
}
