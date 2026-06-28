part of 'presence_bloc.dart';

/// Immutable state for [PresenceBloc]: the set of live shoppers. An empty set
/// means the presence banner is hidden (never a stale "shopping" state).
final class PresenceState extends Equatable {
  /// Creates a [PresenceState] from a shopper list.
  const PresenceState(this.shoppers);

  /// No one is shopping.
  const PresenceState.empty() : shoppers = const <Shopper>[];

  /// People actively shopping right now.
  final List<Shopper> shoppers;

  /// Whether anyone is shopping (drives banner visibility).
  bool get isActive => shoppers.isNotEmpty;

  @override
  List<Object?> get props => [shoppers];
}
