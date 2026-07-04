/// A notification-plugin-agnostic failure with a friendly [message],
/// mirroring how `services/networking` maps `DioException` to
/// `NetworkException` instead of leaking
/// `package:flutter_local_notifications`'s exception types across the
/// service boundary.
class LocalNotificationException implements Exception {
  /// Creates a [LocalNotificationException].
  const LocalNotificationException(this.message);

  /// A human-readable description of the failure.
  final String message;

  @override
  String toString() => 'LocalNotificationException: $message';
}
