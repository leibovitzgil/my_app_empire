part of 'list_bloc.dart';

/// High-level phase of the list screen.
enum ListStatus {
  /// Waiting for the first stream snapshot.
  loading,

  /// A list is loaded (covers empty, populated and syncing — derived from the
  /// [GroceryList] itself).
  ready,

  /// The stream failed to load (offers a retry).
  error,
}

/// Immutable state for [ListBloc].
final class ListState extends Equatable {
  const ListState._({
    required this.status,
    this.list,
    this.flagsOnly = false,
    this.error,
    this.actionError,
  });

  /// Initial loading state.
  const ListState.loading() : this._(status: ListStatus.loading);

  /// Hard error state with a [message].
  const ListState.error(String message)
    : this._(status: ListStatus.error, error: message);

  /// Current phase.
  final ListStatus status;

  /// The loaded list, or null while loading/errored.
  final GroceryList? list;

  /// Whether the "items that need attention" filter is active.
  final bool flagsOnly;

  /// Error message when [status] is [ListStatus.error].
  final String? error;

  /// Transient message for a failed mutation (surfaced as a snackbar, then
  /// cleared by the next stream snapshot). Distinct from the hard [error].
  final String? actionError;

  /// Returns a ready state for [list], preserving the current filter and
  /// clearing any transient [actionError].
  ListState toReady(GroceryList list) =>
      ListState._(status: ListStatus.ready, list: list, flagsOnly: flagsOnly);

  /// Returns a copy with the given overrides (preserving list and status).
  ListState copyWith({bool? flagsOnly}) => ListState._(
    status: status,
    list: list,
    flagsOnly: flagsOnly ?? this.flagsOnly,
    error: error,
  );

  /// Returns a copy carrying a transient [message] for a failed mutation.
  ListState withActionError(String message) => ListState._(
    status: status,
    list: list,
    flagsOnly: flagsOnly,
    error: error,
    actionError: message,
  );

  @override
  List<Object?> get props => [status, list, flagsOnly, error, actionError];
}
