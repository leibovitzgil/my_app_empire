import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSearchField', () {
    testWidgets('hides the clear button when empty', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppSearchField(controller: controller)),
        ),
      );

      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('shows the clear button once text is entered', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppSearchField(controller: controller)),
        ),
      );

      await tester.enterText(find.byType(AppSearchField), 'milk');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('tapping clear resets the controller and calls onClear', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'milk');
      addTearDown(controller.dispose);
      var cleared = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchField(
              controller: controller,
              onClear: () {
                cleared++;
                controller.clear();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(cleared, 1);
      expect(controller.text, isEmpty);
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('defaults onClear to clearing and firing onChanged', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'milk');
      addTearDown(controller.dispose);
      String? changed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchField(
              controller: controller,
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(changed, isEmpty);
    });

    testWidgets('shows a progress indicator instead of clear when loading', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'milk');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchField(controller: controller, isLoading: true),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('exposes the hint as the accessible label', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppSearchField(controller: controller)),
        ),
      );

      expect(find.bySemanticsLabel('Search'), findsOneWidget);
      handle.dispose();
    });
  });
}
