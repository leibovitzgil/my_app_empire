import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryGroceryRepository', () {
    final fixedNow = DateTime(2026, 6, 28, 12);
    const me = GrocerySeed.you;
    late InMemoryGroceryRepository repo;

    setUp(() {
      repo = InMemoryGroceryRepository(demo: false, clock: () => fixedNow);
    });
    tearDown(() async => repo.dispose());

    Future<GroceryList> snapshot() => repo.watchList().first;

    GroceryItem itemNamed(GroceryList list, String name) =>
        list.items.firstWhere((i) => i.name == name);

    test('watchList emits the seeded list as the first event (F1)', () async {
      final list = await snapshot();
      expect(list.active, isNotEmpty);
      expect(list.items.any((i) => i.name == 'Milk'), isTrue);
    });

    test(
      'addItem adds + categorizes; duplicate name is a no-op (F5)',
      () async {
        final before = (await snapshot()).items.length;
        final result = await repo.addItem('Yogurt', by: me);
        expect(result.isSuccess, isTrue);

        final added = itemNamed(await snapshot(), 'Yogurt');
        expect(added.category, ItemCategory.dairy);
        expect(added.addedBy, me);

        await repo.addItem('yogurt', by: me); // idempotent re-add
        final after = await snapshot();
        expect(
          after.items.where((i) => i.name.toLowerCase() == 'yogurt').length,
          1,
        );
        expect(after.items.length, before + 1);
      },
    );

    test(
      'cycleStatus advances needed -> inCart -> done -> needed (F2)',
      () async {
        final milk = itemNamed(await snapshot(), 'Milk');

        await repo.cycleStatus(milk.id, by: me);
        var updated = itemNamed(await snapshot(), 'Milk');
        expect(updated.status, ItemStatus.inCart);
        expect(updated.statusBy, me);

        await repo.cycleStatus(milk.id, by: me);
        updated = itemNamed(await snapshot(), 'Milk');
        expect(updated.status, ItemStatus.done);

        await repo.cycleStatus(milk.id, by: me);
        updated = itemNamed(await snapshot(), 'Milk');
        expect(updated.status, ItemStatus.needed);
      },
    );

    test(
      'setFlag + reactOnIt; clearing a flag removes reactions (F4)',
      () async {
        final milk = itemNamed(await snapshot(), 'Milk');

        await repo.setFlag(milk.id, ItemFlag.outOfStock, by: GrocerySeed.dana);
        var updated = itemNamed(await snapshot(), 'Milk');
        expect(updated.flag, ItemFlag.outOfStock);
        expect(updated.flagBy, GrocerySeed.dana);

        await repo.reactOnIt(milk.id, by: me);
        await repo.reactOnIt(milk.id, by: me); // dedupes
        updated = itemNamed(await snapshot(), 'Milk');
        expect(updated.reactions, [me]);

        await repo.setFlag(milk.id, null, by: me);
        updated = itemNamed(await snapshot(), 'Milk');
        expect(updated.flag, isNull);
        expect(updated.reactions, isEmpty);
      },
    );

    test('deleteItem tombstones; restoreItem brings it back (F6)', () async {
      final milk = itemNamed(await snapshot(), 'Milk');

      await repo.deleteItem(milk.id, by: me);
      var snap = await snapshot();
      expect(snap.active.any((i) => i.id == milk.id), isFalse);
      expect(snap.deleted.any((i) => i.id == milk.id), isTrue);

      await repo.restoreItem(milk.id);
      snap = await snapshot();
      expect(snap.active.any((i) => i.id == milk.id), isTrue);
      expect(snap.deleted.any((i) => i.id == milk.id), isFalse);
    });

    test('clearDone tombstones every done item (F6 bulk)', () async {
      final doneBefore = (await snapshot()).done;
      expect(doneBefore, isNotEmpty);

      await repo.clearDone(by: me);
      final snap = await snapshot();
      expect(snap.done, isEmpty);
      expect(snap.deleted.length, greaterThanOrEqualTo(doneBefore.length));
    });

    test("two subscribers both see one writer's change (F1 sync)", () async {
      final a = <GroceryList>[];
      final b = <GroceryList>[];
      final subA = repo.watchList().listen(a.add);
      final subB = repo.watchList().listen(b.add);
      await pumpEventQueue();

      await repo.addItem('Olive oil', by: me);
      await pumpEventQueue();

      expect(a.last.items.any((i) => i.name == 'Olive oil'), isTrue);
      expect(b.last.items.any((i) => i.name == 'Olive oil'), isTrue);

      await subA.cancel();
      await subB.cancel();
    });

    test('presence: enter shows a shopper, leave removes them (F3)', () async {
      await repo.enter(GrocerySeed.dana);
      final shopping = await repo.watchShoppers().first;
      expect(shopping.map((s) => s.collaborator), contains(GrocerySeed.dana));

      await repo.leave(GrocerySeed.dana.id);
      expect(await repo.watchShoppers().first, isEmpty);
    });

    test('presence auto-clears once the TTL elapses (F3)', () async {
      var now = DateTime(2026, 6, 28, 12);
      final ttlRepo = InMemoryGroceryRepository(demo: false, clock: () => now);
      addTearDown(ttlRepo.dispose);

      await ttlRepo.enter(GrocerySeed.dana);
      expect(await ttlRepo.watchShoppers().first, isNotEmpty);

      now = now.add(const Duration(seconds: 31));
      ttlRepo.pruneStalePresence();
      expect(await ttlRepo.watchShoppers().first, isEmpty);
    });
  });
}
