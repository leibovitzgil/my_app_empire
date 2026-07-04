/// A rendering-library-agnostic PDF failure with a friendly [message],
/// mirroring how `services/networking` maps `DioException` to
/// `NetworkException` instead of leaking `package:pdfx`'s exception types
/// across the service boundary.
class PdfRenderException implements Exception {
  /// Creates a [PdfRenderException].
  const PdfRenderException(this.message);

  /// A human-readable description of the failure.
  final String message;

  @override
  String toString() => 'PdfRenderException: $message';
}
