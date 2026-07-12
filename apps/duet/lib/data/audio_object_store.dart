import 'package:core_utils/core_utils.dart';

/// The raw per-piece audio-object transfer to/from cloud storage
/// (`pieces/{pieceId}/audio/{assetId}`, per `docs/duet_cloud_schema.md`).
///
/// `CloudAudioAssetStore` hides Firebase behind this seam so its local-cache +
/// upload-queue orchestration stays unit-testable with a fake; the Firebase
/// implementation (`FirebaseAudioObjectStore`) is emulator-verified.
abstract class AudioObjectStore {
  /// Uploads the file at [localPath] as the audio object for [assetId] on
  /// [pieceId].
  Future<Result<void>> upload({
    required String pieceId,
    required String assetId,
    required String localPath,
  });

  /// Downloads the audio object for [assetId] on [pieceId] to [destPath].
  Future<Result<void>> download({
    required String pieceId,
    required String assetId,
    required String destPath,
  });

  /// Deletes the audio object for [assetId] on [pieceId] (a no-op if absent).
  Future<Result<void>> delete({
    required String pieceId,
    required String assetId,
  });
}
