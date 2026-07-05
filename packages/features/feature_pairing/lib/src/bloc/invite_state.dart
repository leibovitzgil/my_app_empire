part of 'invite_bloc.dart';

/// The phase of [InviteBloc]'s invite sheet.
enum InviteStatus {
  /// Running the paywall-gate check.
  checkingAccess,

  /// At/over the free-tier student limit — the caller should show
  /// `feature_paywall`'s `PaywallScreen` instead of the normal sheet body.
  paywallRequired,

  /// Access granted; ready to create (or re-create, after a failure) a link.
  ready,

  /// [InviteService.createInvite] is in flight.
  creating,

  /// A link was created.
  created,

  /// [InviteService.createInvite] failed; the sheet stays open for retry.
  failure,
}

/// Immutable state for [InviteBloc].
final class InviteState extends Equatable {
  const InviteState._({
    this.status = InviteStatus.checkingAccess,
    this.link,
    this.error,
  });

  /// The initial state, before [InviteSheetOpened] resolves.
  const InviteState.initial() : this._();

  /// The current phase.
  final InviteStatus status;

  /// The created invite link, once [status] is [InviteStatus.created].
  final InviteLink? link;

  /// The most recent failure, if any.
  final String? error;

  /// Returns a copy with the given fields replaced.
  InviteState copyWith({
    InviteStatus? status,
    InviteLink? link,
    String? error,
    bool clearError = false,
  }) {
    return InviteState._(
      status: status ?? this.status,
      link: link ?? this.link,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, link, error];
}
