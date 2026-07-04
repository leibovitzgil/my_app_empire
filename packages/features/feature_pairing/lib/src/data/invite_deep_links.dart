import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';

/// The shareable-link format `DeepLinkInviteService` mints and this helper
/// recognizes: `https://duet.app/invite/<token>`.
///
/// `services/deep_linking`'s [DeepLinkService] only *consumes* an
/// already-launched [Uri] via an app-supplied `DeepLinkParser` — it has no
/// notion of minting a link. So the format itself is owned here, by the
/// service that creates invite links, and exposed as a small, pure helper so
/// the app-glue layer's `DeepLinkParser` (see
/// `apps/duet/lib/routing/app_deep_link_parser.dart`) can recognize an
/// invite link and extract its token without duplicating this format.
abstract final class InviteDeepLinks {
  /// The host invite links are minted under.
  static const String host = 'duet.app';

  /// The path prefix invite links use, before the token.
  static const String pathPrefix = '/invite/';

  /// Builds the shareable [Uri] for [token].
  static Uri buildUri(String token) =>
      Uri(scheme: 'https', host: host, path: '$pathPrefix$token');

  /// Extracts the invite token from [uri], or fails with an
  /// [UnrecognizedLinkException] if [uri] isn't a recognized invite link.
  static Result<String> tokenFrom(Uri uri) {
    if (uri.host != host || !uri.path.startsWith(pathPrefix)) {
      return ResultFailure<String>(UnrecognizedLinkException(uri));
    }
    final token = uri.path.substring(pathPrefix.length);
    if (token.isEmpty) {
      return ResultFailure<String>(UnrecognizedLinkException(uri));
    }
    return Success(token);
  }
}
