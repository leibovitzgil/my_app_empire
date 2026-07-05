import 'package:record/record.dart' as record;

/// A narrow seam over `package:record`'s `AudioRecorder` so
/// `RecordAudioRecorderService`'s cap-timer and state-transition logic can be
/// unit tested without a platform channel (the real recorder needs a device
/// or emulator).
abstract class RecorderPort {
  /// Whether microphone permission is currently granted.
  Future<bool> hasPermission();

  /// Starts recording to [path] using [config].
  Future<void> start(record.RecordConfig config, {required String path});

  /// Stops the current recording, returning the output path if any.
  Future<String?> stop();

  /// Releases the recorder's native resources.
  Future<void> dispose();
}

/// The default [RecorderPort], backed by a real [record.AudioRecorder].
class PackageRecorderPort implements RecorderPort {
  /// Creates a [PackageRecorderPort] wrapping a fresh [record.AudioRecorder].
  PackageRecorderPort() : _recorder = record.AudioRecorder();

  final record.AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(record.RecordConfig config, {required String path}) =>
      _recorder.start(config, path: path);

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> dispose() => _recorder.dispose();
}
