import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:feature_grocery_list/src/domain/membership_repository.dart';

part 'members_event.dart';
part 'members_state.dart';

/// Drives the share sheet's member roster. Subscribes to the repository's
/// member stream in its constructor (like `PresenceBloc`); invite and remove
/// actions are forwarded to the repository and surfaced as a transient
/// [MembersState.actionMessage] (success) or [MembersState.actionError]
/// (failure), cleared by the next snapshot.
class MembersBloc extends Bloc<MembersEvent, MembersState> {
  /// Creates a [MembersBloc].
  MembersBloc({
    required MembershipRepository repository,
    required Collaborator currentUser,
  }) : _repository = repository,
       _me = currentUser,
       super(const MembersState.loading()) {
    on<MembersUpdated>(_onUpdated);
    on<MemberInvited>(_onInvited);
    on<MemberRemoved>(_onRemoved);
    _subscription = _repository.watchMembers().listen(
      (members) => add(MembersUpdated(members)),
    );
  }

  final MembershipRepository _repository;
  final Collaborator _me;
  late final StreamSubscription<List<ListMember>> _subscription;

  /// The current device user, so the UI can render "You" and gate removal.
  Collaborator get currentUser => _me;

  /// The shareable invite link for this list.
  String get inviteLink => _repository.inviteLink();

  void _onUpdated(MembersUpdated event, Emitter<MembersState> emit) {
    emit(state.toReady(event.members));
  }

  Future<void> _onInvited(
    MemberInvited event,
    Emitter<MembersState> emit,
  ) async {
    final result = await _repository.inviteByEmail(event.email);
    emit(
      result.fold<MembersState>(
        (member) => state.withMessage(
          member.isPending
              ? 'Invited ${member.collaborator.name}'
              : '${member.collaborator.name} is already on this list',
        ),
        (error) => state.withError(_messageFor(error)),
      ),
    );
  }

  Future<void> _onRemoved(
    MemberRemoved event,
    Emitter<MembersState> emit,
  ) async {
    final result = await _repository.removeMember(event.collaboratorId);
    if (result case ResultFailure<void>(:final error)) {
      emit(state.withError(_messageFor(error)));
    }
  }

  String _messageFor(Object error) => error is MembershipException
      ? error.message
      : "Couldn't sync — please try again";

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
