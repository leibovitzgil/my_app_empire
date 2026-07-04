import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTextButton', () {
    testWidgets('renders its label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextButton(label: 'Skip', onPressed: null),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('invokes onPressed when tapped', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextButton(label: 'Skip', onPressed: () => pressed++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppTextButton));
      expect(pressed, 1);
    });

    testWidgets('shows a loader and disables tap when loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextButton(
              label: 'Skip',
              onPressed: null,
              isLoading: true,
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('renders and invokes onPressed when destructive', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextButton(
              label: 'Delete',
              onPressed: () => pressed++,
              isDestructive: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppTextButton));
      expect(pressed, 1);
    });
  });
}
