import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/pairing/src/domain/invite_service.dart';
import 'package:equatable/equatable.dart';
import 'package:monetization/monetization.dart';

part 'accept_invite_state.dart';

/// Drives the Accept Invite screen (the tokenized deep-link/secondary path —
/// see `feature_pairing`'s package doc for how this relates to the primary
/// email-invite path): resolves an invite token, then re-checks the same
/// per-piece collaborator cap (`CollaboratorLimits`) the email path uses
/// before allowing acceptance — surfacing [AcceptInviteStatus.atCap]/
/// [AcceptInviteStatus.alreadyCollaborator] instead of a generic failure so
/// the UI can render a tailored body for each. The caller can simply
/// navigate away to decline — there's nothing to undo server-side.
///
/// A [Cubit] rather than a [Bloc] — like `feature_library`'s
/// `PieceDetailCubit` — since it's a simple, externally-triggered
/// load-then-act flow rather than event-driven branching.
class AcceptInviteCubit extends Cubit<AcceptInviteState> {
  /// Creates an [AcceptInviteCubit] for [collaboratorId] accepting [token].
  AcceptInviteCubit({
    required InviteService inviteService,
    required PieceRepository pieceRepository,
    required MonetizationService monetizationService,
    required this.token,
    required this.collaboratorId,
    this.collaboratorName,
    this.collaboratorEmail,
  }) : _inviteService = inviteService,
       _pieceRepository = pieceRepository,
       _monetization = monetizationService,
       super(const AcceptInviteState.initial());

  /// The invite token to resolve/accept.
  final String token;

  /// The accepting collaborator's id.
  final String collaboratorId;

  /// The accepting collaborator's display name, if known — passed through to
  /// [InviteService.acceptInvite].
  final String? collaboratorName;

  /// The accepting collaborator's email, if known — passed through to
  /// [InviteService.acceptInvite] (AC-2: acceptance records uid+email).
  final String? collaboratorEmail;

  final InviteService _inviteService;
  final PieceRepository _pieceRepository;
  final MonetizationService _monetization;

  /// Resolves [token] to its piece/owner details, then checks whether the
  /// accepter is already a collaborator or the piece is at its cap.
  Future<void> load() async {
    emit(state.copyWith(status: AcceptInviteStatus.loading, clearError: true));
    final result = await _inviteService.resolveInvite(token);
    switch (result) {
      case Success<InviteDetails>(:final value):
        await _checkAccess(value);
      case ResultFailure<InviteDetails>(:final error):
        emit(
          state.copyWith(status: AcceptInviteStatus.failure, error: '$error'),
        );
    }
  }

  Future<void> _checkAccess(InviteDetails details) async {
    final pieceResult = await _pieceRepository.getPiece(details.pieceId);
    switch (pieceResult) {
      case Success<Piece>(:final value):
        if (value.isCollaborator(collaboratorId)) {
          emit(
            state.copyWith(
              status: AcceptInviteStatus.alreadyCollaborator,
              details: details,
            ),
          );
          return;
        }
        final isPro = await _monetization.isProUser();
        if (CollaboratorLimits.isAtCap(value, isPro)) {
          emit(
            state.copyWith(status: AcceptInviteStatus.atCap, details: details),
          );
          return;
        }
        emit(
          state.copyWith(status: AcceptInviteStatus.ready, details: details),
        );
      case ResultFailure<Piece>(:final error):
        emit(
          state.copyWith(status: AcceptInviteStatus.failure, error: '$error'),
        );
    }
  }

  /// Accepts the invite, pairing [collaboratorId] to its piece.
  Future<void> accept() async {
    if (state.status != AcceptInviteStatus.ready) return;
    emit(
      state.copyWith(status: AcceptInviteStatus.accepting, clearError: true),
    );
    final result = await _inviteService.acceptInvite(
      token,
      collaboratorId: collaboratorId,
      collaboratorName: collaboratorName,
      collaboratorEmail: collaboratorEmail,
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
