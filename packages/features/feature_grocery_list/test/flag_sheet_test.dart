import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:feature_grocery_list/src/ui/flag_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('showFlagSheet', () {
    const me = GrocerySeed.you;
    final now = DateTime(2026, 6, 28, 12);

    GroceryItem buildItem({ItemFlag? flag, Collaborator? flagBy}) =>
        GroceryItem(
          id: 'x',
          name: 'Eggs',
          category: ItemCategory.dairy,
          addedBy: me,
          addedAt: now,
          status: ItemStatus.needed,
          statusBy: me,
          statusAt: now,
          updatedAt: now,
          flag: flag,
          flagBy: flag == null ? null : flagBy,
        );

    Future<void> open(WidgetTester tester, GroceryItem item) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showFlagSheet(
                  context: context,
                  item: item,
                  currentUser: me,
                  onFlag: (_) {},
                  onClear: () {},
                  onReact: () {},
                  onDelete: () {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('unflagged item: flag options + delete, no On it/clear', (
      tester,
    ) async {
      await open(tester, buildItem());
      expect(find.text('Out of stock'), findsOneWidget);
      expect(find.text('Get extra'), findsOneWidget);
      expect(find.text('Delete item'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('On it'), findsNothing);
      expect(find.text('Clear flag'), findsNothing);
    });

    testWidgets("another member's flag shows On it + Clear flag (F4)", (
      tester,
    ) async {
      await open(
        tester,
        buildItem(flag: ItemFlag.outOfStock, flagBy: GrocerySeed.dana),
      );
      expect(find.text('On it'), findsOneWidget);
      expect(find.text('Clear flag'), findsOneWidget);
    });
  });
}
