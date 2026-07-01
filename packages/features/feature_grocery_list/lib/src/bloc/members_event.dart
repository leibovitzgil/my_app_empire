part of 'members_bloc.dart';

/// Base type for [MembersBloc] events.
sealed class MembersEvent extends Equatable {
  const MembersEvent();

  @override
  List<Object?> get props => [];
}

/// Internal: a fresh member roster arrived from the repository stream.
final class MembersUpdated extends MembersEvent {
  const MembersUpdated(this.members);

  final List<ListMember> members;

  @override
  List<Object?> get props => [members];
}

/// Invite a person to the list by email.
final class MemberInvited extends MembersEvent {
  const MemberInvited(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Remove a member from the list (the owner cannot be removed).
final class MemberRemoved extends MembersEvent {
  const MemberRemoved(this.collaboratorId);

  final String collaboratorId;

  @override
  List<Object?> get props => [collaboratorId];
}
