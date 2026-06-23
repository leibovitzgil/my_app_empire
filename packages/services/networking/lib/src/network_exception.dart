import 'package:dio/dio.dart';

/// A transport-agnostic network failure with a friendly [message] and the
/// HTTP [statusCode] when one is available.
class NetworkException implements Exception {
  const NetworkException(this.message, {this.statusCode});

  /// Maps a [DioException] to a [NetworkException].
  factory NetworkException.fromDio(DioException error) {
    final status = error.response?.statusCode;
    final message = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The connection timed out. Please try again.',
      DioExceptionType.connectionError =>
        'No internet connection. Please check your network.',
      DioExceptionType.badResponse =>
        'The server returned an error${status != null ? ' ($status)' : ''}.',
      _ => error.message ?? 'An unexpected network error occurred.',
    };
    return NetworkException(message, statusCode: status);
  }

  /// A human-readable description of the failure.
  final String message;

  /// The HTTP status code, when the failure carries one.
  final int? statusCode;

  @override
  String toString() => 'NetworkException($statusCode): $message';
}
