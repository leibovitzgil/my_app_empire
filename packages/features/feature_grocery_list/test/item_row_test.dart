import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:feature_grocery_list/src/ui/item_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ItemRow', () {
    const me = GrocerySeed.you;
    final now = DateTime(2026, 6, 28, 12);

    GroceryItem buildItem({
      ItemStatus status = ItemStatus.needed,
      ItemFlag? flag,
      Collaborator? statusBy,
    }) {
      return GroceryItem(
        id: 'x',
        name: 'Milk',
        category: ItemCategory.dairy,
        addedBy: GrocerySeed.sam,
        addedAt: now,
        status: status,
        statusBy: statusBy ?? GrocerySeed.sam,
        statusAt: now,
        updatedAt: now,
        flag: flag,
        flagBy: flag == null ? null : GrocerySeed.dana,
      );
    }

    Widget host(
      GroceryItem item, {
      VoidCallback? onAdvance,
      VoidCallback? onFlag,
      VoidCallback? onDelete,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ItemRow(
            item: item,
            currentUser: me,
            onAdvance: onAdvance ?? () {},
            onFlagRequested: onFlag ?? () {},
            onDelete: onDelete ?? () {},
          ),
        ),
      );
    }

    testWidgets('renders name and added-by attribution', (tester) async {
      await tester.pumpWidget(host(buildItem()));
      expect(find.text('Milk'), findsOneWidget);
      expect(find.textContaining('Added by Sam'), findsOneWidget);
    });

    testWidgets('tapping the row fires onAdvance (status seam, F2)', (
      tester,
    ) async {
      var advanced = 0;
      await tester.pumpWidget(host(buildItem(), onAdvance: () => advanced++));
      await tester.tap(find.text('Milk'));
      await tester.pump();
      expect(advanced, 1);
    });

    testWidgets('long-press fires onFlagRequested (F4)', (tester) async {
      var flagged = 0;
      await tester.pumpWidget(host(buildItem(), onFlag: () => flagged++));
      await tester.longPress(find.text('Milk'));
      await tester.pump();
      expect(flagged, 1);
    });

    testWidgets('shows the flag chip and in-cart attribution (F2/F4)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          buildItem(
            status: ItemStatus.inCart,
            statusBy: GrocerySeed.dana,
            flag: ItemFlag.outOfStock,
          ),
        ),
      );
      expect(find.text('Out of stock'), findsOneWidget);
      expect(find.textContaining('In cart · Dana'), findsOneWidget);
    });
  });
}
