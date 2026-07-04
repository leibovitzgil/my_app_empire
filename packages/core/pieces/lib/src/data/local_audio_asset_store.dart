import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pieces/src/domain/audio_asset_store.dart';

/// An [AudioAssetStore] that copies recorded audio files into a persistent
/// on-device `audio_notes/` directory (resolved via `path_provider` by
/// default; injectable for tests), keyed by a generated asset id.
class LocalAudioAssetStore implements AudioAssetStore {
  /// Creates a [LocalAudioAssetStore]. [documentsDirectory] defaults to
  /// `getApplicationDocumentsDirectory`; override in tests with a temp dir.
  LocalAudioAssetStore({
    Future<Directory> Function()? documentsDirectory,
    DateTime Function()? clock,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _now = clock ?? DateTime.now;

  final Future<Directory> Function() _documentsDirectory;
  final DateTime Function() _now;
  int _seq = 0;

  Future<Directory> _assetsDir() async {
    final documentsDir = await _documentsDirectory();
    final dir = Directory(p.join(documentsDir.path, 'audio_notes'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  String _nextId() => 'audio_${_now().microsecondsSinceEpoch}_${_seq++}';

  Future<File?> _find(Directory dir, String assetId) async {
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
  Future<Result<String>> put(String sourcePath) =>
      Result.guard<String>(() async {
        final dir = await _assetsDir();
        final id = _nextId();
        final destPath = p.join(dir.path, '$id${p.extension(sourcePath)}');
        await File(sourcePath).copy(destPath);
        return id;
      });

  @override
  Future<Result<String>> pathFor(String assetId) =>
      Result.guard<String>(() async {
        final dir = await _assetsDir();
        final file = await _find(dir, assetId);
        if (file == null) {
          throw StateError('Unknown audio asset: $assetId');
        }
        return file.path;
      });

  @override
  Future<Result<void>> delete(String assetId) => Result.guard<void>(() async {
    final dir = await _assetsDir();
    final file = await _find(dir, assetId);
    if (file != null) await file.delete();
  });
}
