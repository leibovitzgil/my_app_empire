part of 'invite_bloc.dart';

sealed class InviteEvent extends Equatable {
  const InviteEvent();

  @override
  List<Object?> get props => [];
}

/// The invite sheet was opened; runs the per-piece paywall-gate check.
final class InviteSheetOpened extends InviteEvent {
  const InviteSheetOpened();
}

/// The owner typed (or cleared) the invitee's email — the primary, live
/// lookup-as-you-type path (see `CollaboratorInviteService.lookupInvitee`).
final class InviteEmailChanged extends InviteEvent {
  /// Creates an [InviteEmailChanged] for the current field value.
  const InviteEmailChanged(this.email);

  /// The current (not-yet-trimmed) field value.
  final String email;

  @override
  List<Object?> get props => [email];
}

/// The owner tapped "Send invite" once the typed email resolved
/// ([InviteStatus.resolved]) to an inviteable recipient.
final class InviteSendRequested extends InviteEvent {
  const InviteSendRequested();
}

/// The owner tapped "Share invite link instead" — the secondary/fallback
/// tokenized deep-link path (see `InviteService.createInvite`), always
/// available alongside the primary email path.
final class InviteLinkCreateRequested extends InviteEvent {
  const InviteLinkCreateRequested();
}
