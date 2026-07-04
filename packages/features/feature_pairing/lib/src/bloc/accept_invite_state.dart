part of 'accept_invite_cubit.dart';

/// The phase of [AcceptInviteCubit]'s accept-invite flow.
enum AcceptInviteStatus { loading, ready, accepting, accepted, failure }

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

  /// The resolved invite details, once [status] is
  /// [AcceptInviteStatus.ready] (or was, before accepting).
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
