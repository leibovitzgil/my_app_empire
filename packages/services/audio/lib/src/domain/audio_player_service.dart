import 'package:audio/src/domain/playback_progress.dart';
import 'package:core_utils/core_utils.dart';

/// Contract for playing back recorded audio notes.
abstract class AudioPlayerService {
  /// Starts playing the audio file at [path].
  Future<Result<void>> play(String path);

  /// Stops playback.
  Future<Result<void>> stop();

  /// Emits playback position updates while a file is playing.
  Stream<PlaybackProgress> get progress;
}
