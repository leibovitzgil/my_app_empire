/// A well-formed [Uri] that no app route matched.
class UnrecognizedLinkException implements Exception {
  const UnrecognizedLinkException(this.uri, {this.reason});

  /// The link that couldn't be matched to a route.
  final Uri uri;

  /// Optional detail about why the parser rejected [uri].
  final String? reason;

  @override
  String toString() =>
      'UnrecognizedLinkException: no route matched $uri'
      '${reason != null ? ' ($reason)' : ''}';
}

/// A raw string that couldn't even parse into a [Uri].
class InvalidLinkException implements Exception {
  const InvalidLinkException(this.rawValue, {this.cause});

  /// The raw value that failed to parse.
  final String rawValue;

  /// The underlying error that caused the parse failure, if any.
  final Object? cause;

  @override
  String toString() =>
      'InvalidLinkException: could not parse "$rawValue"'
      '${cause != null ? ' ($cause)' : ''}';
}
