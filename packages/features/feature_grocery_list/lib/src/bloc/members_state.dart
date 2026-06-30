part of 'members_bloc.dart';

/// High-level phase of the share sheet.
enum MembersStatus {
  /// Waiting for the first roster snapshot.
  loading,

  /// The roster is loaded.
  ready,
}

/// Immutable state for [MembersBloc].
final class MembersState extends Equatable {
  const MembersState._({
    required this.status,
    this.members = const <ListMember>[],
    this.actionMessage,
    this.actionError,
  });

  /// Initial loading state.
  const MembersState.loading() : this._(status: MembersStatus.loading);

  /// Current phase.
  final MembersStatus status;

  /// The current member roster.
  final List<ListMember> members;

  /// Transient success message (e.g. "Invited Sam"), surfaced as a snackbar and
  /// cleared by the next roster snapshot.
  final String? actionMessage;

  /// Transient failure message (e.g. an invalid email), surfaced as a snackbar.
  final String? actionError;

  /// Returns a ready state for [members], clearing any transient messages.
  MembersState toReady(List<ListMember> members) =>
      MembersState._(status: MembersStatus.ready, members: members);

  /// Returns a copy carrying a transient success [message].
  MembersState withMessage(String message) => MembersState._(
    status: status,
    members: members,
    actionMessage: message,
  );

  /// Returns a copy carrying a transient failure [message].
  MembersState withError(String message) => MembersState._(
    status: status,
    members: members,
    actionError: message,
  );

  @override
  List<Object?> get props => [status, members, actionMessage, actionError];
}
