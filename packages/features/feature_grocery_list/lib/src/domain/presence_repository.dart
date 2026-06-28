import 'package:feature_grocery_list/src/domain/grocery_models.dart';

/// Contract for live "who is shopping right now" presence. Kept separate from
/// the grocery repository so heartbeat churn never rebuilds the whole list,
/// even though one in-memory class implements both today.
abstract class PresenceRepository {
  /// Emits the current set of active shoppers, TTL-filtered, on every change.
  Stream<List<Shopper>> watchShoppers();

  /// Marks [who] as actively shopping and starts their presence TTL.
  Future<void> enter(Collaborator who);

  /// Refreshes a shopper's TTL so they stay visible while active.
  Future<void> heartbeat(String collaboratorId);

  /// Removes a shopper from presence (e.g. they left the store / screen).
  Future<void> leave(String collaboratorId);
}
