import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:feature_grocery_list/src/domain/presence_repository.dart';

part 'presence_event.dart';
part 'presence_state.dart';

/// Tracks who is actively shopping the list. Kept separate from the list bloc
/// so heartbeats and presence churn never rebuild the whole list.
class PresenceBloc extends Bloc<PresenceEvent, PresenceState> {
  /// Creates a [PresenceBloc].
  PresenceBloc({
    required PresenceRepository repository,
    required Collaborator currentUser,
  }) : _repository = repository,
       _me = currentUser,
       super(const PresenceState.empty()) {
    on<PresenceUpdated>(_onUpdated);
    on<ShoppingEntered>(_onEntered);
    on<ShoppingLeft>(_onLeft);
    _subscription = _repository.watchShoppers().listen(
      (shoppers) => add(PresenceUpdated(shoppers)),
    );
  }

  final PresenceRepository _repository;
  final Collaborator _me;
  late final StreamSubscription<List<Shopper>> _subscription;

  void _onUpdated(PresenceUpdated event, Emitter<PresenceState> emit) {
    emit(PresenceState(event.shoppers));
  }

  Future<void> _onEntered(
    ShoppingEntered event,
    Emitter<PresenceState> emit,
  ) async {
    await _repository.enter(_me);
  }

  Future<void> _onLeft(ShoppingLeft event, Emitter<PresenceState> emit) async {
    await _repository.leave(_me.id);
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
