part of 'invite_inbox_cubit.dart';

/// One-shot outcome of the most recent accept/dismiss action, consumed by
/// the banner's `BlocConsumer` listener (snackbar/navigation/paywall) and
/// reset to [idle] whenever a new action starts.
enum InviteInboxStatus {
  /// No outcome pending.
  idle,

  /// The last accept completed — [InviteInboxState.acceptedPieceId] holds
  /// the now-joined piece.
  accepted,

  /// The last accept was refused by the collaborator-cap re-check
  /// ([AtCapInviteException]) — the UI should defer to the paywall gate.
  atCap,

  /// The last action failed for any other reason — see
  /// [InviteInboxState.error].
  failure,
}

/// State for [InviteInboxCubit]: the live pending-invite list plus the
/// in-flight/outcome bookkeeping for accept/dismiss.
final class InviteInboxState extends Equatable {
  /// Creates an [InviteInboxState].
  const InviteInboxState({
    this.invites = const [],
    this.busyMessageIds = const {},
    this.status = InviteInboxStatus.idle,
    this.acceptedPieceId,
    this.error,
  });

  /// The pending invites addressed to the current user, live from
  /// `CollaboratorInviteService.watchInvites`.
  final List<InviteMessage> invites;

  /// Message ids with an accept/dismiss currently in flight.
  final Set<String> busyMessageIds;

  /// See [InviteInboxStatus].
  final InviteInboxStatus status;

  /// The piece joined by the accept that produced
  /// [InviteInboxStatus.accepted], if any.
  final String? acceptedPieceId;

  /// The user-facing message for [InviteInboxStatus.failure], if any.
  final String? error;

  /// Copies this state. [clearOutcome] resets [acceptedPieceId]/[error]
  /// (used when a new action starts).
  InviteInboxState copyWith({
    List<InviteMessage>? invites,
    Set<String>? busyMessageIds,
    InviteInboxStatus? status,
    String? acceptedPieceId,
    String? error,
    bool clearOutcome = false,
  }) => InviteInboxState(
    invites: invites ?? this.invites,
    busyMessageIds: busyMessageIds ?? this.busyMessageIds,
    status: status ?? this.status,
    acceptedPieceId: clearOutcome
        ? acceptedPieceId
        : (acceptedPieceId ?? this.acceptedPieceId),
    error: clearOutcome ? error : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    invites,
    busyMessageIds,
    status,
    acceptedPieceId,
    error,
  ];
}
