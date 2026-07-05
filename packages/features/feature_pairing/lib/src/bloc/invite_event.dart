part of 'invite_bloc.dart';

sealed class InviteEvent extends Equatable {
  const InviteEvent();

  @override
  List<Object?> get props => [];
}

/// The invite sheet was opened; runs the paywall-gate check.
final class InviteSheetOpened extends InviteEvent {
  const InviteSheetOpened();
}

/// The user tapped "Get invite link".
final class InviteLinkCreateRequested extends InviteEvent {
  const InviteLinkCreateRequested();
}
