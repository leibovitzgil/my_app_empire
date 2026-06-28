import 'package:core_utils/core_utils.dart';
import 'package:feature_grocery_list/src/domain/grocery_models.dart';

/// Contract for the shared grocery list. The bloc depends only on this, so the
/// in-memory implementation can be swapped for a Firestore/Supabase one with no
/// changes to events, states or UI.
///
/// Real-time reads are exposed as a [Stream]; one-shot mutations return a
/// [Result] so callers never have to catch across the boundary.
abstract class GroceryRepository {
  /// Emits the full list on subscribe, then a new snapshot on every change
  /// (from this device or any other collaborator).
  Stream<GroceryList> watchList();

  /// Adds an item by name. The name is categorised automatically. Adding a name
  /// that already exists (case-insensitively) among live items is a no-op so
  /// retries stay idempotent.
  Future<Result<GroceryItem>> addItem(String name, {required Collaborator by});

  /// Advances an item's status: needed -> in-cart -> done -> needed.
  Future<Result<void>> cycleStatus(String itemId, {required Collaborator by});

  /// Sets an item's status explicitly, restamping attribution to [by].
  Future<Result<void>> setStatus(
    String itemId,
    ItemStatus status, {
    required Collaborator by,
  });

  /// Sets or clears (pass `null`) an item's flag.
  Future<Result<void>> setFlag(
    String itemId,
    ItemFlag? flag, {
    required Collaborator by,
  });

  /// Records a one-tap "On it" reaction from [by] on a flagged item.
  Future<Result<void>> reactOnIt(String itemId, {required Collaborator by});

  /// Tombstones an item (reversible — see [restoreItem]).
  Future<Result<void>> deleteItem(String itemId, {required Collaborator by});

  /// Restores a tombstoned item (add-wins).
  Future<Result<void>> restoreItem(String itemId);

  /// Clears all done items as an undoable bulk tombstone.
  Future<Result<void>> clearDone({required Collaborator by});
}
