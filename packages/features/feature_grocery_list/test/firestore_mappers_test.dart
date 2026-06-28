import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:feature_grocery_list/src/data/firestore_mappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('firestore mappers', () {
    test('itemToMap/itemFromMap round-trips an item', () {
      final now = DateTime(2026, 6, 28, 12);
      final item = GroceryItem(
        id: 'x',
        name: 'Milk',
        category: ItemCategory.dairy,
        addedBy: GrocerySeed.sam,
        addedAt: now,
        status: ItemStatus.inCart,
        statusBy: GrocerySeed.dana,
        statusAt: now,
        updatedAt: now,
        flag: ItemFlag.urgent,
        flagBy: GrocerySeed.dana,
        reactions: const [GrocerySeed.you],
      );

      final back = itemFromMap('x', itemToMap(item));
      expect(back, item);
    });

    test('itemFromMap defaults gracefully on unknown enum names', () {
      final now = Timestamp.fromDate(DateTime(2026, 6, 28, 12));
      final person = <String, dynamic>{
        'id': 'me',
        'name': 'You',
        'colorValue': 1,
      };
      final back = itemFromMap('y', <String, dynamic>{
        'name': 'Mystery',
        'category': 'not-a-category',
        'status': 'not-a-status',
        'addedBy': person,
        'addedAt': now,
        'statusBy': person,
        'statusAt': now,
        'updatedAt': now,
        'reactions': <dynamic>[],
        'isDeleted': false,
      });

      expect(back.category, ItemCategory.other);
      expect(back.status, ItemStatus.needed);
      expect(back.flag, isNull);
    });
  });
}
