part of 'invite_bloc.dart';

/// The phase of [InviteBloc]'s invite sheet.
enum InviteStatus {
  /// Running the per-piece paywall-gate check.
  checkingAccess,

  /// At/over the collaborator cap already — the caller should show
  /// `feature_paywall`'s `PaywallScreen` instead of the normal sheet body.
  paywallRequired,

  /// Access granted; no email typed (or it was just cleared) yet.
  ready,

  /// [CollaboratorInviteService.lookupInvitee] is in flight for the
  /// currently-typed email.
  lookingUp,

  /// The typed email resolved to an inviteable [InviteState.recipient].
  resolved,

  /// The typed email has no discoverable account — the caller should surface
  /// the link-fallback affordance.
  notFound,

  /// The typed email resolves to someone already a collaborator here.
  alreadyCollaborator,

  /// [CollaboratorInviteService.sendInvite] or [InviteService.createInvite]
  /// is in flight.
  sending,

  /// An invite was sent (email path, [InviteState.recipient] set) or a link
  /// was created (link-fallback path, [InviteState.link] set).
  sent,
}

/// Immutable state for [InviteBloc].
final class InviteState extends Equatable {
  const InviteState._({
    this.status = InviteStatus.checkingAccess,
    this.email = '',
    this.recipient,
    this.link,
    this.error,
  });

  /// The initial state, before [InviteSheetOpened] resolves.
  const InviteState.initial() : this._();

  /// The current phase.
  final InviteStatus status;

  /// The email currently typed into the invite field (last value the bloc
  /// has seen via [InviteEmailChanged]).
  final String email;

  /// The resolved recipient, once [status] is [InviteStatus.resolved] or
  /// [InviteStatus.sent] (email path).
  final InviteRecipient? recipient;

  /// The created invite link, once [status] is [InviteStatus.sent] (link
  /// fallback path).
  final InviteLink? link;

  /// The most recent failure, if any.
  final String? error;

  /// Returns a copy with the given fields replaced.
  InviteState copyWith({
    InviteStatus? status,
    String? email,
    InviteRecipient? recipient,
    InviteLink? link,
    String? error,
    bool clearRecipient = false,
    bool clearError = false,
  }) {
    return InviteState._(
      status: status ?? this.status,
      email: email ?? this.email,
      recipient: clearRecipient ? null : (recipient ?? this.recipient),
      link: link ?? this.link,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, email, recipient, link, error];
}
