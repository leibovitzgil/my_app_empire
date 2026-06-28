part of 'presence_bloc.dart';

/// Base type for [PresenceBloc] events.
sealed class PresenceEvent extends Equatable {
  const PresenceEvent();

  @override
  List<Object?> get props => [];
}

/// Internal: a fresh shopper set arrived from the presence stream.
final class PresenceUpdated extends PresenceEvent {
  const PresenceUpdated(this.shoppers);

  final List<Shopper> shoppers;

  @override
  List<Object?> get props => [shoppers];
}

/// The current user entered shopping mode.
final class ShoppingEntered extends PresenceEvent {
  const ShoppingEntered();
}

/// The current user left shopping mode.
final class ShoppingLeft extends PresenceEvent {
  const ShoppingLeft();
}
