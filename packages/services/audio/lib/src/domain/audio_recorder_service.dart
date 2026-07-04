import 'package:core_utils/core_utils.dart';

/// Contract for recording short audio notes to disk.
abstract class AudioRecorderService {
  /// Starts recording to [outputPath], stopping automatically after
  /// [maxMillis] if [stop] isn't called first.
  Future<Result<void>> start(String outputPath, {int maxMillis = 60000});

  /// Stops the current recording, returning the path it was written to.
  Future<Result<String>> stop();

  /// Emits the elapsed recording time while a recording is in progress.
  Stream<Duration> get elapsed;
}
