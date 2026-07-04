import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_pairing/src/domain/invite_service.dart';

part 'accept_invite_state.dart';

/// Drives the Accept Invite screen: resolves an invite token, then accepts
/// (or the caller can simply navigate away to decline — there's nothing to
/// undo server-side for a decline).
///
/// A [Cubit] rather than a [Bloc] — like `feature_library`'s
/// `PieceDetailCubit` — since it's a simple, externally-triggered
/// load-then-act flow rather than event-driven branching.
class AcceptInviteCubit extends Cubit<AcceptInviteState> {
  /// Creates an [AcceptInviteCubit] for [studentId] accepting [token].
  AcceptInviteCubit({
    required InviteService inviteService,
    required this.token,
    required this.studentId,
  }) : _inviteService = inviteService,
       super(const AcceptInviteState.initial());

  /// The invite token to resolve/accept.
  final String token;

  /// The accepting student's id.
  final String studentId;

  final InviteService _inviteService;

  /// Resolves [token] to its piece/teacher details.
  Future<void> load() async {
    emit(state.copyWith(status: AcceptInviteStatus.loading, clearError: true));
    final result = await _inviteService.resolveInvite(token);
    switch (result) {
      case Success<InviteDetails>(:final value):
        emit(state.copyWith(status: AcceptInviteStatus.ready, details: value));
      case ResultFailure<InviteDetails>(:final error):
        emit(
          state.copyWith(status: AcceptInviteStatus.failure, error: '$error'),
        );
    }
  }

  /// Accepts the invite, pairing [studentId] to its piece.
  Future<void> accept() async {
    if (state.status != AcceptInviteStatus.ready) return;
    emit(
      state.copyWith(status: AcceptInviteStatus.accepting, clearError: true),
    );
    final result = await _inviteService.acceptInvite(
      token,
      studentId: studentId,
    );
    switch (result) {
      case Success<void>():
        emit(state.copyWith(status: AcceptInviteStatus.accepted));
      case ResultFailure<void>(:final error):
        emit(
          state.copyWith(
            status: AcceptInviteStatus.ready,
            error: '$error',
          ),
        );
    }
  }
}
