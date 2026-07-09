import 'dart:async';

/// Tracks the current user's latest known email from
/// `AuthAccountProvider.account`, exposing it synchronously via [call] —
/// mirrors `CurrentUser`/`CurrentUserName`'s pattern exactly (see
/// `CurrentUser`'s doc for why eager construction/subscription matters),
/// but for an email rather than an id or display name.
///
/// Consumed by `feature_pairing`'s accept-invite flow
/// (`PieceRepository.addCollaborator`/`AcceptInvitePage.collaboratorEmail`)
/// so an accepted collaborator's email is recorded on the piece instead of
/// left `null`.
class CurrentUserEmail {
  /// Creates a [CurrentUserEmail], subscribing to [emailStream] immediately.
  CurrentUserEmail(Stream<String?> emailStream) {
    _subscription = emailStream.listen((email) => _email = email);
  }

  late final StreamSubscription<String?> _subscription;
  String? _email;

  /// The latest known email, or `null` when signed out / not yet known /
  /// unresolvable — callers should treat `null` as "no email to attach"
  /// rather than an error.
  String? call() => _email;

  /// Releases the subscription to the email stream.
  Future<void> dispose() => _subscription.cancel();
}
