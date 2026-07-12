import 'package:core_utils/core_utils.dart';

/// Contract for storing and retrieving recorded audio-note assets.
///
/// Every operation is scoped to a [String] `pieceId` because audio objects are
/// per-piece (`pieces/{pieceId}/audio/{assetId}` in cloud storage, per
/// `docs/duet_cloud_schema.md`): an upload needs the piece to path the object,
/// and a *collaborator* resolving a note they didn't record must download it by
/// piece. The on-device store ignores `pieceId` (its layout is flat); the cloud
/// store (M3.5) needs it.
abstract class AudioAssetStore {
  /// Copies the audio file at [sourcePath] into managed storage for [pieceId],
  /// returning the id it was stored under.
  Future<Result<String>> put(String sourcePath, {required String pieceId});

  /// Resolves a readable local path for [assetId] on [pieceId], downloading it
  /// on a cache miss (cloud store).
  Future<Result<String>> pathFor(String assetId, {required String pieceId});

  /// Removes the stored asset for [assetId] on [pieceId].
  Future<Result<void>> delete(String assetId, {required String pieceId});
}
