import 'package:just_audio/just_audio.dart' as just_audio;

/// A narrow seam over `package:just_audio`'s `AudioPlayer` so
/// `JustAudioPlayerService`'s progress-composition logic can be unit tested
/// without a platform channel (the real player needs a device or emulator).
abstract class PlayerPort {
  /// Loads the file at [path] as the current audio source.
  Future<void> setFilePath(String path);

  /// Starts (or resumes) playback of the current source.
  Future<void> play();

  /// Stops playback.
  Future<void> stop();

  /// Emits playback position updates.
  Stream<Duration> get positionStream;

  /// Emits the current source's duration once known (or `null`).
  Stream<Duration?> get durationStream;

  /// Releases the player's native resources.
  Future<void> dispose();
}

/// The default [PlayerPort], backed by a real [just_audio.AudioPlayer].
class PackagePlayerPort implements PlayerPort {
  /// Creates a [PackagePlayerPort] wrapping a fresh
  /// [just_audio.AudioPlayer].
  PackagePlayerPort() : _player = just_audio.AudioPlayer();

  final just_audio.AudioPlayer _player;

  @override
  Future<void> setFilePath(String path) async {
    await _player.setFilePath(path);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Future<void> dispose() => _player.dispose();
}
