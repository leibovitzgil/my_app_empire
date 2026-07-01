import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ListScreen', () {
    const me = GrocerySeed.you;
    final now = DateTime(2026, 6, 28, 12);
    late InMemoryGroceryRepository repo;

    setUp(() {
      repo = InMemoryGroceryRepository(demo: false, clock: () => now);
    });
    tearDown(() async => repo.dispose());

    Future<void> pumpScreen(WidgetTester tester) async {
      // A tall viewport so the whole (lazily-built) list renders in tests.
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: GroceryListPage(
            repository: repo,
            presence: repo,
            membership: repo,
            currentUser: me,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows seeded items grouped by category (F1 populated)', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Bananas'), findsOneWidget);
      expect(find.text('Produce'), findsOneWidget);
    });

    testWidgets('tapping an item advances its status + attribution (F2)', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.textContaining('Added by Sam'), findsOneWidget); // Bananas

      await tester.tap(find.text('Bananas'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Added by Sam'), findsNothing);
      expect(find.textContaining('In cart · you'), findsWidgets);
    });

    testWidgets('adding an item shows it under a category (F5)', (
      tester,
    ) async {
      await pumpScreen(tester);
      // 'Paprika' has no catalogue suggestions, so the keyboard action submits
      // the typed text directly (no autocomplete overlay to interfere).
      await tester.enterText(find.byType(TextField), 'Paprika');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Paprika'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('attention summary is hidden when nothing is flagged (F4)', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.textContaining('need attention'), findsNothing);
    });
  });
}
