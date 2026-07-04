import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';

/// Matches deep links to app_template's routes ([`/`], [`/home`]). Real apps
/// replace this with matching against their own `go_router` routes.
Result<DeepLinkIntent> appTemplateDeepLinkParser(Uri uri) {
  return switch (uri.path) {
    '' || '/' => const Success(DeepLinkIntent(location: '/')),
    '/home' => const Success(DeepLinkIntent(location: '/home')),
    _ => ResultFailure<DeepLinkIntent>(UnrecognizedLinkException(uri)),
  };
}
