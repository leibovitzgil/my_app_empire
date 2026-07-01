import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';

/// Matches deep links to showcase's funnel screens (home, paywall, settings).
/// Showcase does not use `go_router`, so this parser is registered in DI as
/// the reference contract implementation but is not yet consulted by the UI
/// (see `apps/app_template` for the reference redirect wiring).
Result<DeepLinkIntent> showcaseDeepLinkParser(Uri uri) {
  return switch (uri.path) {
    '' || '/' || '/home' => const Success(DeepLinkIntent(location: '/home')),
    '/paywall' => const Success(DeepLinkIntent(location: '/paywall')),
    '/settings' => const Success(DeepLinkIntent(location: '/settings')),
    _ => ResultFailure<DeepLinkIntent>(UnrecognizedLinkException(uri)),
  };
}
