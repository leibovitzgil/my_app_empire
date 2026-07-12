import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/features/pairing/pairing.dart';

/// Matches deep links to Duet's routes ([`/`], [`/home`]) and to
/// `feature_pairing`'s invite-link format
/// (`https://duet.app/invite/<token>`, see `InviteDeepLinks`).
///
/// An invite link's token is embedded directly in the resulting
/// [DeepLinkIntent.location] (`/invite/accept/<token>`) rather than in
/// [DeepLinkIntent.parameters] — `AppView`'s `_redirect` only ever threads a
/// plain location string from a pending intent through to `go_router`, so
/// putting the token in the path keeps that mechanism unchanged.
Result<DeepLinkIntent> duetDeepLinkParser(Uri uri) {
  final inviteToken = InviteDeepLinks.tokenFrom(uri);
  if (inviteToken case Success<String>(:final value)) {
    return Success(DeepLinkIntent(location: '/invite/accept/$value'));
  }
  return switch (uri.path) {
    '' || '/' => const Success(DeepLinkIntent(location: '/')),
    '/home' => const Success(DeepLinkIntent(location: '/home')),
    _ => ResultFailure<DeepLinkIntent>(UnrecognizedLinkException(uri)),
  };
}
