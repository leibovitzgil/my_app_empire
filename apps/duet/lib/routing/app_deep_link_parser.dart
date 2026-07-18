import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/features/pairing/pairing.dart';

/// Matches deep links to Duet's routes ([`/`], [`/home`]), to
/// `feature_pairing`'s invite-link format
/// (`https://duet.app/invite/<token>`, see `InviteDeepLinks`), and to the
/// piece links a push notification carries
/// (`https://duet.app/piece/<pieceId>` — the exact shape M5.3's
/// `onInboxMessageCreated` function emits as `data.deepLink`), which route
/// onto the existing `/score/:pieceId` destination (M5.5).
///
/// An invite link's token — and likewise a piece link's id — is embedded
/// directly in the resulting [DeepLinkIntent.location]
/// (`/invite/accept/<token>`, `/score/<pieceId>`) rather than in
/// [DeepLinkIntent.parameters] — `AppView`'s `_redirect` only ever threads a
/// plain location string from a pending intent through to `go_router`, so
/// putting it in the path keeps that mechanism unchanged. Whether the id
/// actually resolves to a reachable piece is not this parser's call (it has
/// no repository): the `/score/:pieceId` route guards that itself, bouncing
/// unknown/denied ids to `/home` with a snackbar (G4).
Result<DeepLinkIntent> duetDeepLinkParser(Uri uri) {
  final inviteToken = InviteDeepLinks.tokenFrom(uri);
  if (inviteToken case Success<String>(:final value)) {
    return Success(DeepLinkIntent(location: '/invite/accept/$value'));
  }
  final pieceId = _pieceIdFrom(uri);
  if (pieceId != null) {
    return Success(
      DeepLinkIntent(location: '/score/${Uri.encodeComponent(pieceId)}'),
    );
  }
  return switch (uri.path) {
    '' || '/' => const Success(DeepLinkIntent(location: '/')),
    '/home' => const Success(DeepLinkIntent(location: '/home')),
    _ => ResultFailure<DeepLinkIntent>(UnrecognizedLinkException(uri)),
  };
}

/// The piece id of a `/piece/<id>` link, or null when [uri] isn't one —
/// exactly two path segments, the second non-empty (`/piece/`,
/// `/piece/a/b` are garbage, not piece links).
String? _pieceIdFrom(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length != 2 || segments.first != 'piece') return null;
  final id = segments[1];
  return id.isEmpty ? null : id;
}
