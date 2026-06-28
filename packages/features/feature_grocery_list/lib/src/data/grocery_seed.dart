import 'package:feature_grocery_list/src/domain/grocery_models.dart';

/// Demo collaborators and a starter list so Tandem feels alive the moment it
/// opens — and so the simulated collaborator has someone to be.
abstract final class GrocerySeed {
  /// The current device's user.
  static const Collaborator you = Collaborator(
    id: 'me',
    name: 'You',
    colorValue: 0xFF3B82F6,
  );

  /// A simulated household member who "shops" the list live in the demo.
  static const Collaborator dana = Collaborator(
    id: 'dana',
    name: 'Dana',
    colorValue: 0xFFEC4899,
  );

  /// Another household member, used for pre-seeded attribution.
  static const Collaborator sam = Collaborator(
    id: 'sam',
    name: 'Sam',
    colorValue: 0xFF10B981,
  );

  /// The id of the single shared list in the MVP.
  static const String listId = 'household';

  /// Builds the starter list relative to [now] so timestamps read naturally.
  static GroceryList initialList(DateTime now) {
    GroceryItem item({
      required String id,
      required String name,
      required ItemCategory category,
      required Collaborator addedBy,
      required Duration addedAgo,
      ItemStatus status = ItemStatus.needed,
      Collaborator? statusBy,
      Duration? statusAgo,
      ItemFlag? flag,
      Collaborator? flagBy,
    }) {
      final added = now.subtract(addedAgo);
      final touched = now.subtract(statusAgo ?? addedAgo);
      return GroceryItem(
        id: id,
        name: name,
        category: category,
        addedBy: addedBy,
        addedAt: added,
        status: status,
        statusBy: statusBy ?? addedBy,
        statusAt: touched,
        updatedAt: touched,
        flag: flag,
        flagBy: flag == null ? null : (flagBy ?? addedBy),
      );
    }

    return GroceryList(
      id: listId,
      name: 'Weekly shop',
      items: <GroceryItem>[
        item(
          id: 'seed_bananas',
          name: 'Bananas',
          category: ItemCategory.produce,
          addedBy: sam,
          addedAgo: const Duration(hours: 1),
        ),
        item(
          id: 'seed_milk',
          name: 'Milk',
          category: ItemCategory.dairy,
          addedBy: you,
          addedAgo: const Duration(minutes: 32),
        ),
        item(
          id: 'seed_eggs',
          name: 'Eggs',
          category: ItemCategory.dairy,
          addedBy: dana,
          addedAgo: const Duration(minutes: 28),
        ),
        item(
          id: 'seed_bread',
          name: 'Bread',
          category: ItemCategory.bakery,
          addedBy: you,
          addedAgo: const Duration(minutes: 26),
          status: ItemStatus.inCart,
          statusBy: you,
          statusAgo: const Duration(minutes: 4),
        ),
        item(
          id: 'seed_chicken',
          name: 'Chicken',
          category: ItemCategory.meat,
          addedBy: you,
          addedAgo: const Duration(minutes: 20),
        ),
        item(
          id: 'seed_toilet_paper',
          name: 'Toilet paper',
          category: ItemCategory.household,
          addedBy: dana,
          addedAgo: const Duration(minutes: 18),
        ),
        item(
          id: 'seed_coffee',
          name: 'Coffee',
          category: ItemCategory.beverages,
          addedBy: sam,
          addedAgo: const Duration(minutes: 40),
          status: ItemStatus.done,
          statusBy: sam,
          statusAgo: const Duration(minutes: 9),
        ),
      ],
    );
  }
}
