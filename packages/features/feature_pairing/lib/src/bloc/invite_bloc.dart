import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_pairing/src/domain/collaborator_invite_service.dart';
import 'package:feature_pairing/src/domain/invite_service.dart';
import 'package:monetization/monetization.dart';
import 'package:pieces/pieces.dart';

part 'invite_event.dart';
part 'invite_state.dart';

/// Drives the Invite sheet: a per-piece paywall-gate check first (checked
/// eagerly so the sheet can defer to `PaywallScreen` instead of ever showing
/// its normal body), then the email-primary invite flow via
/// [CollaboratorInviteService] (live lookup-as-you-type, then send), with the
/// tokenized deep-link [InviteService] always available as a secondary
/// fallback ("Share invite link instead").
class InviteBloc extends Bloc<InviteEvent, InviteState> {
  /// Creates an [InviteBloc] for [teacherId] inviting a collaborator to
  /// [pieceId].
  InviteBloc({
    required CollaboratorInviteService collaboratorInviteService,
    required InviteService inviteService,
    required MonetizationService monetizationService,
    required PieceRepository pieceRepository,
    required this.teacherId,
    required this.pieceId,
    this.teacherName,
  }) : _collaboratorInviteService = collaboratorInviteService,
       _inviteService = inviteService,
       _monetization = monetizationService,
       _pieceRepository = pieceRepository,
       super(const InviteState.initial()) {
    on<InviteSheetOpened>(_onOpened);
    on<InviteEmailChanged>(_onEmailChanged);
    on<InviteSendRequested>(_onSendRequested);
    on<InviteLinkCreateRequested>(_onLinkCreateRequested);
  }

  /// The inviting owner's id.
  final String teacherId;

  /// The piece being invited for.
  final String pieceId;

  /// The inviting owner's display name, if known — passed through to
  /// [CollaboratorInviteService.sendInvite] and
  /// [InviteService.createInvite].
  final String? teacherName;

  final CollaboratorInviteService _collaboratorInviteService;
  final InviteService _inviteService;
  final MonetizationService _monetization;
  final PieceRepository _pieceRepository;

  static const Set<InviteStatus> _gated = {
    InviteStatus.checkingAccess,
    InviteStatus.paywallRequired,
    InviteStatus.sending,
  };

  Future<void> _onOpened(
    InviteSheetOpened event,
    Emitter<InviteState> emit,
  ) async {
    emit(state.copyWith(status: InviteStatus.checkingAccess));
    final pieceResult = await _pieceRepository.getPiece(pieceId);
    switch (pieceResult) {
      case Success<Piece>(:final value):
        final isPro = await _monetization.isProUser();
        emit(
          state.copyWith(
            status: CollaboratorLimits.isAtCap(value, isPro)
                ? InviteStatus.paywallRequired
                : InviteStatus.ready,
          ),
        );
      case ResultFailure<Piece>(:final error):
        emit(state.copyWith(status: InviteStatus.ready, error: '$error'));
    }
  }

  Future<void> _onEmailChanged(
    InviteEmailChanged event,
    Emitter<InviteState> emit,
  ) async {
    if (_gated.contains(state.status)) return;
    final email = event.email.trim();
    if (email.isEmpty) {
      emit(
        state.copyWith(
          status: InviteStatus.ready,
          email: email,
          clearRecipient: true,
          clearError: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: InviteStatus.lookingUp,
        email: email,
        clearRecipient: true,
        clearError: true,
      ),
    );
    final result = await _collaboratorInviteService.lookupInvitee(
      pieceId: pieceId,
      email: email,
    );
    // A newer keystroke may have superseded this in-flight lookup (the
    // default `bloc` event transformer processes events concurrently) —
    // drop a stale response rather than clobbering a fresher one.
    if (state.email != email) return;
    switch (result) {
      case Success<LookupOutcome>(:final value):
        emit(
          state.copyWith(
            status: _statusFor(value),
            recipient: _recipientFor(value),
          ),
        );
      case ResultFailure<LookupOutcome>(:final error):
        emit(state.copyWith(status: InviteStatus.ready, error: '$error'));
    }
  }

  Future<void> _onSendRequested(
    InviteSendRequested event,
    Emitter<InviteState> emit,
  ) async {
    if (state.status != InviteStatus.resolved) return;
    final email = state.email;
    emit(state.copyWith(status: InviteStatus.sending, clearError: true));
    final result = await _collaboratorInviteService.sendInvite(
      pieceId: pieceId,
      ownerId: teacherId,
      email: email,
      ownerName: teacherName,
    );
    switch (result) {
      case Success<LookupOutcome>(:final value):
        if (value is Resolved) {
          emit(
            state.copyWith(
              status: InviteStatus.sent,
              recipient: value.recipient,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: _statusFor(value),
              recipient: _recipientFor(value),
            ),
          );
        }
      case ResultFailure<LookupOutcome>(:final error):
        emit(
          state.copyWith(status: InviteStatus.resolved, error: '$error'),
        );
    }
  }

  Future<void> _onLinkCreateRequested(
    InviteLinkCreateRequested event,
    Emitter<InviteState> emit,
  ) async {
    if (_gated.contains(state.status)) return;
    final fallbackStatus = state.status;
    emit(state.copyWith(status: InviteStatus.sending, clearError: true));
    final result = await _inviteService.createInvite(
      teacherId: teacherId,
      pieceId: pieceId,
      teacherName: teacherName,
    );
    switch (result) {
      case Success<InviteLink>(:final value):
        emit(state.copyWith(status: InviteStatus.sent, link: value));
      case ResultFailure<InviteLink>(:final error):
        emit(state.copyWith(status: fallbackStatus, error: '$error'));
    }
  }

  static InviteStatus _statusFor(LookupOutcome outcome) => switch (outcome) {
    Resolved() => InviteStatus.resolved,
    NoAccount() => InviteStatus.notFound,
    AlreadyCollaborator() => InviteStatus.alreadyCollaborator,
    AtCap() => InviteStatus.paywallRequired,
  };

  static InviteRecipient? _recipientFor(LookupOutcome outcome) =>
      outcome is Resolved ? outcome.recipient : null;
}
