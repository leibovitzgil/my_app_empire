import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:feature_grocery_list/src/domain/grocery_repository.dart';

part 'list_event.dart';
part 'list_state.dart';

/// Drives the shared grocery list. Subscribes to the repository stream in its
/// constructor (like `AuthBloc`) so remote changes flow in as [ListUpdated]
/// events; user actions are forwarded to the repository, whose new snapshot
/// then updates state — a single source of truth that stays correct when the
/// real backend lands.
///
/// Mutations return a `Result` but their failure case is not yet surfaced as
/// error UI: the in-memory repo's only failure (an empty name) is guarded at
/// the call site, and per-row sync/error feedback lands with the offline-outbox
/// work (F7). The contract returns `Result` today so that wiring is a UI change
/// only, not a repository change.
class ListBloc extends Bloc<ListEvent, ListState> {
  /// Creates a [ListBloc].
  ListBloc({
    required GroceryRepository repository,
    required Collaborator currentUser,
  }) : _repository = repository,
       _me = currentUser,
       super(const ListState.loading()) {
    on<ListUpdated>(_onUpdated);
    on<ListSubscriptionFailed>(_onFailed);
    on<ItemAdded>(_onItemAdded);
    on<StatusCycled>(_onStatusCycled);
    on<StatusSet>(_onStatusSet);
    on<ItemFlagged>(_onItemFlagged);
    on<FlagCleared>(_onFlagCleared);
    on<ReactedOnIt>(_onReactedOnIt);
    on<ItemDeleted>(_onItemDeleted);
    on<ItemRestored>(_onItemRestored);
    on<DoneCleared>(_onDoneCleared);
    on<FlagsOnlyToggled>(_onFlagsOnlyToggled);
    on<ListRetryRequested>(_onRetry);
    _subscribe();
  }

  final GroceryRepository _repository;
  final Collaborator _me;
  late StreamSubscription<GroceryList> _subscription;

  void _subscribe() {
    _subscription = _repository.watchList().listen(
      (list) => add(ListUpdated(list)),
      onError: (Object error) => add(ListSubscriptionFailed(error.toString())),
    );
  }

  Future<void> _onRetry(
    ListRetryRequested event,
    Emitter<ListState> emit,
  ) async {
    emit(const ListState.loading());
    await _subscription.cancel();
    _subscribe();
  }

  // Surfaces a failed mutation as a transient action error (snackbar in the
  // UI), without disturbing the optimistic stream-driven list.
  void _surfaceFailure(Result<Object?> result, Emitter<ListState> emit) {
    if (!result.isSuccess) {
      emit(state.withActionError("Couldn't sync — please try again"));
    }
  }

  /// The current device's user, so the UI can render "you" vs a member name.
  Collaborator get currentUser => _me;

  void _onUpdated(ListUpdated event, Emitter<ListState> emit) {
    emit(state.toReady(event.list));
  }

  void _onFailed(ListSubscriptionFailed event, Emitter<ListState> emit) {
    emit(ListState.error(event.message));
  }

  Future<void> _onItemAdded(ItemAdded event, Emitter<ListState> emit) async {
    _surfaceFailure(await _repository.addItem(event.name, by: _me), emit);
  }

  Future<void> _onStatusCycled(
    StatusCycled event,
    Emitter<ListState> emit,
  ) async {
    _surfaceFailure(
      await _repository.cycleStatus(event.itemId, by: _me),
      emit,
    );
  }

  Future<void> _onStatusSet(StatusSet event, Emitter<ListState> emit) async {
    _surfaceFailure(
      await _repository.setStatus(event.itemId, event.status, by: _me),
      emit,
    );
  }

  Future<void> _onItemFlagged(
    ItemFlagged event,
    Emitter<ListState> emit,
  ) async {
    _surfaceFailure(
      await _repository.setFlag(event.itemId, event.flag, by: _me),
      emit,
    );
  }

  Future<void> _onFlagCleared(
    FlagCleared event,
    Emitter<ListState> emit,
  ) async {
    _surfaceFailure(
      await _repository.setFlag(event.itemId, null, by: _me),
      emit,
    );
  }

  Future<void> _onReactedOnIt(
    ReactedOnIt event,
    Emitter<ListState> emit,
  ) async {
    _surfaceFailure(await _repository.reactOnIt(event.itemId, by: _me), emit);
  }

  Future<void> _onItemDeleted(
    ItemDeleted event,
    Emitter<ListState> emit,
  ) async {
    _surfaceFailure(await _repository.deleteItem(event.itemId, by: _me), emit);
  }

  Future<void> _onItemRestored(
    ItemRestored event,
    Emitter<ListState> emit,
  ) async {
    _surfaceFailure(await _repository.restoreItem(event.itemId), emit);
  }

  Future<void> _onDoneCleared(
    DoneCleared event,
    Emitter<ListState> emit,
  ) async {
    _surfaceFailure(await _repository.clearDone(by: _me), emit);
  }

  void _onFlagsOnlyToggled(FlagsOnlyToggled event, Emitter<ListState> emit) {
    emit(state.copyWith(flagsOnly: !state.flagsOnly));
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
