/// A playback-plugin-agnostic failure with a friendly [message], mirroring
/// how `services/networking` maps `DioException` to `NetworkException`
/// instead of leaking `package:just_audio`'s exception types across the
/// service boundary.
class AudioPlaybackException implements Exception {
  /// Creates an [AudioPlaybackException].
  const AudioPlaybackException(this.message);

  /// A human-readable description of the failure.
  final String message;

  @override
  String toString() => 'AudioPlaybackException: $message';
}
