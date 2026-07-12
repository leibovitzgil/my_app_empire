import 'dart:async';
import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:duet/data/audio_object_store.dart';
import 'package:duet/data/audio_upload_queue.dart';
import 'package:duet/domain/domain.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// An [AudioAssetStore] backed by Cloud Storage — the cloud counterpart to
/// [LocalAudioAssetStore].
///
///  - **`put`** copies the recording into the on-device `audio_notes/` cache
///    (so it plays back instantly and survives the recording's temp file), then
///    **enqueues** an upload and kicks a best-effort drain. A note recorded
///    offline stays queued and uploads when [AudioUploadQueue.drain] next runs
///    (connectivity/app-start), so it isn't lost.
///  - **`pathFor`** returns the cached file when present; on a miss (a
///    collaborator resolving a note they didn't record) it downloads the object
///    into the cache and returns that.
///  - **`delete`** removes the remote object (best-effort — an offline failure
///    is swallowed; the M3.8 cascade reconciles orphans) and evicts the local
///    copy.
///
/// Storage transfer is delegated to [AudioObjectStore] (Firebase impl
/// emulator-verified); everything here is fake-testable. Not wired into DI
/// yet — M3.6 flips `useFirebase`.
class CloudAudioAssetStore implements AudioAssetStore {
  /// Creates a [CloudAudioAssetStore].
  CloudAudioAssetStore({
    required AudioObjectStore objectStore,
    required AudioUploadQueue uploadQueue,
    Future<Directory> Function()? documentsDirectory,
    DateTime Function()? clock,
  }) : _objectStore = objectStore,
       _uploadQueue = uploadQueue,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _now = clock ?? DateTime.now;

  static const String _dirName = 'audio_notes';

  final AudioObjectStore _objectStore;
  final AudioUploadQueue _uploadQueue;
  final Future<Directory> Function() _documentsDirectory;
  final DateTime Function() _now;
  int _seq = 0;

  String _nextId() => 'audio_${_now().microsecondsSinceEpoch}_${_seq++}';

  Future<Directory> _cacheDir() async {
    final documents = await _documentsDirectory();
    final dir = Directory(p.join(documents.path, _dirName));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<File?> _find(String assetId) async {
    final dir = await _cacheDir();
    if (!dir.existsSync()) return null;
    await for (final entity in dir.list()) {
      if (entity is File &&
          p.basenameWithoutExtension(entity.path) == assetId) {
        return entity;
      }
    }
    return null;
  }

  @override
  Future<Result<String>> put(String sourcePath, {required String pieceId}) =>
      Result.guard<String>(() async {
        final dir = await _cacheDir();
        final id = _nextId();
        final destPath = p.join(dir.path, '$id${p.extension(sourcePath)}');
        await File(sourcePath).copy(destPath);
        await _uploadQueue.enqueue(
          AudioUploadTask(pieceId: pieceId, assetId: id, localPath: destPath),
        );
        // Best-effort immediate upload; a failure just leaves it queued.
        unawaited(drainUploads());
        return id;
      });

  @override
  Future<Result<String>> pathFor(String assetId, {required String pieceId}) =>
      Result.guard<String>(() async {
        final cached = await _find(assetId);
        if (cached != null) return cached.path;
        // Not on this device (a collaborator's note, or evicted) — download it.
        final dir = await _cacheDir();
        final destPath = p.join(dir.path, '$assetId.m4a');
        (await _objectStore.download(
          pieceId: pieceId,
          assetId: assetId,
          destPath: destPath,
        )).orThrow();
        return destPath;
      });

  @override
  Future<Result<void>> delete(String assetId, {required String pieceId}) =>
      Result.guard<void>(() async {
        // Remote delete is best-effort: an offline failure shouldn't block the
        // local eviction (the M3.8 cascade cleans up any orphaned object).
        await _objectStore.delete(pieceId: pieceId, assetId: assetId);
        final cached = await _find(assetId);
        if (cached != null) await cached.delete();
      });

  /// Drains the pending upload queue (call on connectivity/app-start). Exposed
  /// so the app can trigger it beyond `put`'s best-effort attempt.
  Future<void> drainUploads() => _uploadQueue.drain(
    (task) => _objectStore.upload(
      pieceId: task.pieceId,
      assetId: task.assetId,
      localPath: task.localPath,
    ),
  );
}
