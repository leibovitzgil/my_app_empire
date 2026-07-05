import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_pairing/src/domain/invite_service.dart';
import 'package:monetization/monetization.dart';
import 'package:pieces/pieces.dart';

part 'invite_event.dart';
part 'invite_state.dart';

/// Drives the Invite sheet: a paywall-gate check first (mirroring
/// `feature_paywall`'s gate, but checked eagerly so the sheet can defer to
/// `PaywallScreen` instead of ever showing its normal body), then invite-link
/// creation via [InviteService].
class InviteBloc extends Bloc<InviteEvent, InviteState> {
  /// Creates an [InviteBloc] for [teacherId] inviting a student to
  /// [pieceId]. [freeTierStudentLimit] must match whatever
  /// `DeepLinkInviteService` is configured with, so the UI-level gate here
  /// and the service's defensive backstop agree.
  InviteBloc({
    required InviteService inviteService,
    required MonetizationService monetizationService,
    required PieceRepository pieceRepository,
    required this.teacherId,
    required this.pieceId,
    this.teacherName,
    this.freeTierStudentLimit = 1,
  }) : _inviteService = inviteService,
       _monetization = monetizationService,
       _pieceRepository = pieceRepository,
       super(const InviteState.initial()) {
    on<InviteSheetOpened>(_onOpened);
    on<InviteLinkCreateRequested>(_onCreateRequested);
  }

  /// The inviting teacher's id.
  final String teacherId;

  /// The piece being invited for.
  final String pieceId;

  /// The inviting teacher's display name, if known — passed through to
  /// [InviteService.createInvite].
  final String? teacherName;

  /// The free tier's paired-student cap.
  final int freeTierStudentLimit;

  final InviteService _inviteService;
  final MonetizationService _monetization;
  final PieceRepository _pieceRepository;

  Future<void> _onOpened(
    InviteSheetOpened event,
    Emitter<InviteState> emit,
  ) async {
    emit(state.copyWith(status: InviteStatus.checkingAccess));
    final isPro = await _monetization.isProUser();
    if (isPro) {
      emit(state.copyWith(status: InviteStatus.ready));
      return;
    }
    final pieces = await _pieceRepository.watchPieces().first;
    final pairedStudents = pieces
        .where((p) => p.teacherId == teacherId && p.studentId != null)
        .map((p) => p.studentId)
        .toSet();
    emit(
      state.copyWith(
        status: pairedStudents.length >= freeTierStudentLimit
            ? InviteStatus.paywallRequired
            : InviteStatus.ready,
      ),
    );
  }

  Future<void> _onCreateRequested(
    InviteLinkCreateRequested event,
    Emitter<InviteState> emit,
  ) async {
    if (state.status != InviteStatus.ready &&
        state.status != InviteStatus.failure) {
      return;
    }
    emit(state.copyWith(status: InviteStatus.creating, clearError: true));
    final result = await _inviteService.createInvite(
      teacherId: teacherId,
      pieceId: pieceId,
      teacherName: teacherName,
    );
    switch (result) {
      case Success<InviteLink>(:final value):
        emit(state.copyWith(status: InviteStatus.created, link: value));
      case ResultFailure<InviteLink>(:final error):
        emit(state.copyWith(status: InviteStatus.failure, error: '$error'));
    }
  }
}
