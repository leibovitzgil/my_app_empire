import 'package:flutter/foundation.dart';

/// A parsed, app-meaningful deep link, decoupled from the raw [Uri].
///
/// [location] is a route path/name string (a go_router path or named
/// route — the app's parser decides its shape); this package does not model
/// app routes.
@immutable
class DeepLinkIntent {
  const DeepLinkIntent({
    required this.location,
    this.parameters = const {},
  });

  /// The destination the app should navigate to.
  final String location;

  /// Extra parameters extracted from the link (query params, path segments).
  final Map<String, String> parameters;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DeepLinkIntent) return false;
    if (location != other.location) return false;
    if (parameters.length != other.parameters.length) return false;
    for (final entry in parameters.entries) {
      if (other.parameters[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    location,
    Object.hashAllUnordered(
      parameters.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'DeepLinkIntent(location: $location, '
      'parameters: $parameters)';
}
