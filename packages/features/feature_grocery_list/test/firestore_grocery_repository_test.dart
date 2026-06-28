import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreGroceryRepository', () {
    const me = GrocerySeed.you;
    const listId = 'household';
    final fixedNow = DateTime(2026, 6, 28, 12);
    late FakeFirebaseFirestore firestore;
    late FirestoreGroceryRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = FirestoreGroceryRepository(
        firestore: firestore,
        listId: listId,
        clock: () => fixedNow,
      );
    });

    Future<GroceryItem> itemNamed(String name) async {
      final list = await repo.watchList().first;
      return list.items.firstWhere((i) => i.name == name);
    }

    test(
      'addItem writes a categorized item, watchList streams it (F1/F5)',
      () async {
        final result = await repo.addItem('Milk', by: me);
        expect(result.isSuccess, isTrue);

        final milk = await itemNamed('Milk');
        expect(milk.category, ItemCategory.dairy);
        expect(milk.addedBy, me);
        expect(milk.status, ItemStatus.needed);
      },
    );

    test('addItem is idempotent by name (F5)', () async {
      await repo.addItem('Bread', by: me);
      await repo.addItem('bread', by: me); // duplicate

      final list = await repo.watchList().first;
      expect(
        list.items.where((i) => i.name.toLowerCase() == 'bread').length,
        1,
      );
    });

    test(
      'cycleStatus advances + re-attributes in a transaction (F2)',
      () async {
        final added = (await repo.addItem('Eggs', by: me)).valueOrNull!;

        await repo.cycleStatus(added.id, by: GrocerySeed.dana);
        final eggs = await itemNamed('Eggs');
        expect(eggs.status, ItemStatus.inCart);
        expect(eggs.statusBy, GrocerySeed.dana);
      },
    );

    test('setFlag + reactOnIt; clearing removes reactions (F4)', () async {
      final added = (await repo.addItem('Apples', by: me)).valueOrNull!;

      await repo.setFlag(added.id, ItemFlag.outOfStock, by: GrocerySeed.dana);
      await repo.reactOnIt(added.id, by: me);
      await repo.reactOnIt(added.id, by: me); // dedupes
      var apples = await itemNamed('Apples');
      expect(apples.flag, ItemFlag.outOfStock);
      expect(apples.reactions, [me]);

      await repo.setFlag(added.id, null, by: me);
      apples = await itemNamed('Apples');
      expect(apples.flag, isNull);
      expect(apples.reactions, isEmpty);
    });

    test('deleteItem tombstones; restoreItem brings it back (F6)', () async {
      final added = (await repo.addItem('Rice', by: me)).valueOrNull!;

      await repo.deleteItem(added.id, by: me);
      var list = await repo.watchList().first;
      expect(list.active.any((i) => i.id == added.id), isFalse);
      expect(list.deleted.any((i) => i.id == added.id), isTrue);

      await repo.restoreItem(added.id);
      list = await repo.watchList().first;
      expect(list.active.any((i) => i.id == added.id), isTrue);
    });

    test('clearDone tombstones all done items (F6 bulk)', () async {
      final tea = (await repo.addItem('Tea', by: me)).valueOrNull!;
      await repo.setStatus(tea.id, ItemStatus.done, by: me);

      await repo.clearDone(by: me);
      final list = await repo.watchList().first;
      expect(list.done, isEmpty);
      expect(list.deleted.any((i) => i.id == tea.id), isTrue);
    });

    test('watchList pushes live updates as a stream (F1 real-time)', () async {
      final emissions = <GroceryList>[];
      final sub = repo.watchList().listen(emissions.add);

      await repo.addItem('Coffee', by: me);
      await pumpEventQueue();

      expect(emissions.last.items.any((i) => i.name == 'Coffee'), isTrue);
      await sub.cancel();
    });
  });
}
