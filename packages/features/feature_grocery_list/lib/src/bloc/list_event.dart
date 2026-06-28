part of 'list_bloc.dart';

/// Base type for [ListBloc] events.
sealed class ListEvent extends Equatable {
  const ListEvent();

  @override
  List<Object?> get props => [];
}

/// Internal: a fresh snapshot arrived from the repository stream.
final class ListUpdated extends ListEvent {
  const ListUpdated(this.list);

  final GroceryList list;

  @override
  List<Object?> get props => [list];
}

/// Internal: the list stream errored (hard load failure).
final class ListSubscriptionFailed extends ListEvent {
  const ListSubscriptionFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Add a new item by name (categorised + de-duplicated by the repository).
final class ItemAdded extends ListEvent {
  const ItemAdded(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

/// Advance an item's status: needed -> in-cart -> done -> needed.
final class StatusCycled extends ListEvent {
  const StatusCycled(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// Set an item's status explicitly (e.g. un-do from the "Got it" section).
final class StatusSet extends ListEvent {
  const StatusSet(this.itemId, this.status);

  final String itemId;
  final ItemStatus status;

  @override
  List<Object?> get props => [itemId, status];
}

/// Raise a flag on an item.
final class ItemFlagged extends ListEvent {
  const ItemFlagged(this.itemId, this.flag);

  final String itemId;
  final ItemFlag flag;

  @override
  List<Object?> get props => [itemId, flag];
}

/// Clear an item's flag.
final class FlagCleared extends ListEvent {
  const FlagCleared(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// One-tap "On it" reaction on a flagged item.
final class ReactedOnIt extends ListEvent {
  const ReactedOnIt(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// Tombstone an item (reversible).
final class ItemDeleted extends ListEvent {
  const ItemDeleted(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// Restore a tombstoned item.
final class ItemRestored extends ListEvent {
  const ItemRestored(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// Clear all done items (undoable bulk tombstone).
final class DoneCleared extends ListEvent {
  const DoneCleared();
}

/// Toggle the "flags only" attention filter.
final class FlagsOnlyToggled extends ListEvent {
  const FlagsOnlyToggled();
}
