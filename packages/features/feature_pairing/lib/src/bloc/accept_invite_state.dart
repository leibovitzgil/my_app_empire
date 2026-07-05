part of 'accept_invite_cubit.dart';

/// The phase of [AcceptInviteCubit]'s accept-invite flow.
enum AcceptInviteStatus {
  /// Resolving [AcceptInviteCubit.token] (and, once resolved, the
  /// accepter's current access to that piece).
  loading,

  /// Resolved and under the collaborator cap — ready to accept.
  ready,

  /// The accepter is already a collaborator on this piece (e.g. re-opening
  /// an already-consumed invite).
  alreadyCollaborator,

  /// The piece is already at its collaborator cap for the owner's current
  /// monetization tier.
  atCap,

  /// [InviteService.acceptInvite] is in flight.
  accepting,

  /// The invite was accepted.
  accepted,

  /// Resolving the token, or accepting, failed.
  failure,
}

/// Immutable state for [AcceptInviteCubit].
final class AcceptInviteState extends Equatable {
  const AcceptInviteState._({
    this.status = AcceptInviteStatus.loading,
    this.details,
    this.error,
  });

  /// The initial state, before [AcceptInviteCubit.load] resolves.
  const AcceptInviteState.initial() : this._();

  /// The current phase.
  final AcceptInviteStatus status;

  /// The resolved invite details, once [status] is [AcceptInviteStatus.ready]
  /// (or was, before accepting) — also populated for
  /// [AcceptInviteStatus.alreadyCollaborator]/[AcceptInviteStatus.atCap], so
  /// the UI can still show the piece title.
  final InviteDetails? details;

  /// The most recent failure (invalid/expired token, or an accept failure),
  /// if any.
  final String? error;

  /// Returns a copy with the given fields replaced.
  AcceptInviteState copyWith({
    AcceptInviteStatus? status,
    InviteDetails? details,
    String? error,
    bool clearError = false,
  }) {
    return AcceptInviteState._(
      status: status ?? this.status,
      details: details ?? this.details,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, details, error];
}
