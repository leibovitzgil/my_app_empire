import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/features/pairing/src/domain/collaborator_invite_service.dart';
import 'package:equatable/equatable.dart';
import 'package:notifications/notifications.dart';

part 'invite_inbox_state.dart';

/// Drives the pending-invite banner on the library surface (M5.6): streams
/// the signed-in user's pending invites from
/// [CollaboratorInviteService.watchInvites], accepts one via the same
/// [CollaboratorInviteService.acceptInvite] path the M2.4 callable backs,
/// and dismisses one by marking the underlying inbox message read (the
/// sender is unaffected — there's nothing to undo server-side).
///
/// A [Cubit] rather than a [Bloc] — like `AcceptInviteCubit` — since it's a
/// simple stream-plus-two-actions surface rather than event-driven
/// branching.
class InviteInboxCubit extends Cubit<InviteInboxState> {
  /// Creates an [InviteInboxCubit] watching [currentUserId]'s invites
  /// immediately.
  InviteInboxCubit({
    required CollaboratorInviteService collaboratorInviteService,
    required UserMessageGateway messageGateway,
    required this.currentUserId,
    this.currentUserName,
    this.currentUserEmail,
  }) : _invites = collaboratorInviteService,
       _messages = messageGateway,
       super(const InviteInboxState()) {
    _subscription = _invites
        .watchInvites(currentUserId)
        .listen((invites) => emit(state.copyWith(invites: invites)));
  }

  /// The signed-in (accepting) user's id.
  final String currentUserId;

  /// The accepting user's display name, if known — passed through to
  /// [CollaboratorInviteService.acceptInvite] (AC-2: acceptance records
  /// uid+email).
  final String? currentUserName;

  /// The accepting user's email, if known — see [currentUserName].
  final String? currentUserEmail;

  final CollaboratorInviteService _invites;
  final UserMessageGateway _messages;
  late final StreamSubscription<List<InviteMessage>> _subscription;

  /// Accepts [invite] on behalf of the current user. Success surfaces as
  /// [InviteInboxStatus.accepted] (the invite leaves [InviteInboxState
  /// .invites] via the stream — acceptance consumes the message); the cap
  /// re-check failing surfaces as [InviteInboxStatus.atCap] so the UI can
  /// defer to the paywall gate.
  Future<void> accept(InviteMessage invite) async {
    if (state.busyMessageIds.contains(invite.messageId)) return;
    emit(
      state.copyWith(
        busyMessageIds: {...state.busyMessageIds, invite.messageId},
        status: InviteInboxStatus.idle,
        clearOutcome: true,
      ),
    );
    final result = await _invites.acceptInvite(
      invite,
      accepterId: currentUserId,
      accepterName: currentUserName,
      accepterEmail: currentUserEmail,
    );
    final busy = {...state.busyMessageIds}..remove(invite.messageId);
    switch (result) {
      case Success<void>():
        emit(
          state.copyWith(
            busyMessageIds: busy,
            status: InviteInboxStatus.accepted,
            acceptedPieceId: invite.pieceId,
          ),
        );
      case ResultFailure<void>(:final error):
        emit(
          state.copyWith(
            busyMessageIds: busy,
            status: error is AtCapInviteException
                ? InviteInboxStatus.atCap
                : InviteInboxStatus.failure,
            error: error is CollaboratorInviteException
                ? error.message
                : '$error',
          ),
        );
    }
  }

  /// Dismisses [invite]: marks the underlying inbox message read — nothing
  /// more. The sender is unaffected, and the invite simply leaves every
  /// [CollaboratorInviteService.watchInvites] snapshot.
  Future<void> dismiss(InviteMessage invite) async {
    if (state.busyMessageIds.contains(invite.messageId)) return;
    emit(
      state.copyWith(
        busyMessageIds: {...state.busyMessageIds, invite.messageId},
        status: InviteInboxStatus.idle,
        clearOutcome: true,
      ),
    );
    final result = await _messages.markRead(currentUserId, invite.messageId);
    final busy = {...state.busyMessageIds}..remove(invite.messageId);
    switch (result) {
      case Success<void>():
        emit(state.copyWith(busyMessageIds: busy));
      case ResultFailure<void>(:final error):
        emit(
          state.copyWith(
            busyMessageIds: busy,
            status: InviteInboxStatus.failure,
            error: '$error',
          ),
        );
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
