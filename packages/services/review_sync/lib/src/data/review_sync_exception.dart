/// A bundling/sharing failure with a friendly [message], mirroring how
/// `services/networking` maps `DioException` to `NetworkException` instead
/// of leaking `package:archive`/`package:share_plus` exception types across
/// the service boundary.
class ReviewSyncException implements Exception {
  /// Creates a [ReviewSyncException].
  const ReviewSyncException(this.message);

  /// A human-readable description of the failure.
  final String message;

  @override
  String toString() => 'ReviewSyncException: $message';
}
