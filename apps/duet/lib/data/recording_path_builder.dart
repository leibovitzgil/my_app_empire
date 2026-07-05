import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Produces a fresh on-device output path for a new audio-note recording.
///
/// `feature_score`'s `ScoreViewerScreen` takes this as a plain, synchronous
/// `String Function()` (so the package itself never needs to depend on
/// `path_provider`) — but resolving the on-device temp directory is
/// inherently async, so [createRecordingPathBuilder] resolves it once, up
/// front, and the returned callable just does synchronous string building
/// from then on.
class RecordingPathBuilder {
  /// Creates a [RecordingPathBuilder] writing into `directory`.
  RecordingPathBuilder(this._directory);

  final Directory _directory;
  int _seq = 0;

  /// Builds a fresh, unique recording output path in [_directory].
  String call() => p.join(
    _directory.path,
    'recording_${DateTime.now().microsecondsSinceEpoch}_${_seq++}.m4a',
  );
}

/// Resolves a persistent `recordings/` directory (under the temp directory,
/// since raw recordings are transient — the durable copy lives in
/// `AudioAssetStore`'s managed storage once a note is saved) and returns a
/// [RecordingPathBuilder] backed by it.
Future<RecordingPathBuilder> createRecordingPathBuilder() async {
  final tempDir = await getTemporaryDirectory();
  final dir = Directory(p.join(tempDir.path, 'recordings'))
    ..createSync(recursive: true);
  return RecordingPathBuilder(dir);
}
