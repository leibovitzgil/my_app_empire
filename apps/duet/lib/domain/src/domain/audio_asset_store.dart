import 'dart:io';

import 'package:core_utils/core_utils.dart';

/// Hard cap on one audio-note asset's size, in bytes (5 MB).
///
/// **Keep in sync with `apps/duet/storage.rules`** — the
/// `pieces/{pieceId}/audio/{assetId}` write rule enforces the same 5 MB
/// server-side (`request.resource.size < 5 * 1024 * 1024`, M8.3); this
/// constant is the client-side backstop every [AudioAssetStore.put] applies
/// before storing/uploading. With the recorder's AAC-LC 64 kbps mono config
/// (`RecordAudioRecorderService.recordConfig`) a max-length 60 s note is
/// ≈ 0.5 MB, so hitting this cap should be unreachable in practice.
const int maxAudioNoteBytes = 5 * 1024 * 1024;

/// Thrown (inside `Result.guard`, so surfaced as a `ResultFailure`) by
/// [AudioAssetStore.put] when a recording is at or over [maxAudioNoteBytes].
class AudioNoteTooLargeException implements Exception {
  /// Creates an [AudioNoteTooLargeException] for a file of [actualBytes].
  const AudioNoteTooLargeException({required this.actualBytes});

  /// The offending file's size in bytes.
  final int actualBytes;

  @override
  String toString() =>
      'Recording too large: $actualBytes bytes '
      '(the audio-note cap is $maxAudioNoteBytes bytes)';
}

/// Shared `put` guard: throws [AudioNoteTooLargeException] when the file at
/// [sourcePath] is at or over [maxAudioNoteBytes]. Every [AudioAssetStore]
/// implementation (local, cloud, and the in-memory fakes) calls this first so
/// the cap behaves identically everywhere (G3). A missing source file passes
/// through — the implementation's own copy/read then fails with the honest
/// missing-file error.
void ensureAudioNoteWithinCap(String sourcePath) {
  final file = File(sourcePath);
  if (!file.existsSync()) return;
  final bytes = file.lengthSync();
  if (bytes >= maxAudioNoteBytes) {
    throw AudioNoteTooLargeException(actualBytes: bytes);
  }
}

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
  /// returning the id it was stored under. Fails with
  /// [AudioNoteTooLargeException] when the file is at or over
  /// [maxAudioNoteBytes] (M8.3).
  Future<Result<String>> put(String sourcePath, {required String pieceId});

  /// Resolves a readable local path for [assetId] on [pieceId], downloading it
  /// on a cache miss (cloud store).
  Future<Result<String>> pathFor(String assetId, {required String pieceId});

  /// Removes the stored asset for [assetId] on [pieceId].
  Future<Result<void>> delete(String assetId, {required String pieceId});
}
