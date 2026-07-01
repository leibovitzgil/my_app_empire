import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';

/// Matches deep links to Tandem's single shared grocery list.
Result<DeepLinkIntent> tandemDeepLinkParser(Uri uri) {
  return switch (uri.pathSegments) {
    [] || ['list'] => const Success(DeepLinkIntent(location: '/list')),
    ['join', final listId] => Success(
      DeepLinkIntent(location: '/list', parameters: {'listId': listId}),
    ),
    _ => ResultFailure<DeepLinkIntent>(UnrecognizedLinkException(uri)),
  };
}
