/// A recording-plugin-agnostic failure with a friendly [message], mirroring
/// how `services/networking` maps `DioException` to `NetworkException`
/// instead of leaking `package:record`'s exception types across the service
/// boundary.
class AudioRecordException implements Exception {
  /// Creates an [AudioRecordException].
  const AudioRecordException(this.message);

  /// A human-readable description of the failure.
  final String message;

  @override
  String toString() => 'AudioRecordException: $message';
}
