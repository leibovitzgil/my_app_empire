import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:feature_grocery_list/src/domain/presence_repository.dart';

part 'presence_event.dart';
part 'presence_state.dart';

/// Tracks who is actively shopping the list. Kept separate from the list bloc
/// so heartbeats and presence churn never rebuild the whole list.
///
/// While the current user is in shopping mode a periodic heartbeat keeps their
/// presence alive (so the TTL never prunes them mid-shop), and closing the bloc
/// — e.g. leaving the list screen — makes them leave presence.
class PresenceBloc extends Bloc<PresenceEvent, PresenceState> {
  /// Creates a [PresenceBloc]. [heartbeatInterval] must be shorter than the
  /// repository's presence TTL.
  PresenceBloc({
    required PresenceRepository repository,
    required Collaborator currentUser,
    Duration heartbeatInterval = const Duration(seconds: 10),
  }) : _repository = repository,
       _me = currentUser,
       _heartbeatInterval = heartbeatInterval,
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
  final Duration _heartbeatInterval;
  late final StreamSubscription<List<Shopper>> _subscription;
  Timer? _heartbeatTimer;

  void _onUpdated(PresenceUpdated event, Emitter<PresenceState> emit) {
    emit(PresenceState(event.shoppers));
  }

  Future<void> _onEntered(
    ShoppingEntered event,
    Emitter<PresenceState> emit,
  ) async {
    await _repository.enter(_me);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      _heartbeatInterval,
      (_) => unawaited(_repository.heartbeat(_me.id)),
    );
  }

  Future<void> _onLeft(ShoppingLeft event, Emitter<PresenceState> emit) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _repository.leave(_me.id);
  }

  @override
  Future<void> close() async {
    _heartbeatTimer?.cancel();
    await _subscription.cancel();
    await _repository.leave(_me.id);
    return super.close();
  }
}
