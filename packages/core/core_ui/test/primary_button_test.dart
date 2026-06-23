import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrimaryButton', () {
    testWidgets('renders its label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrimaryButton(label: 'Tap me', onPressed: null),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tap me'), findsOneWidget);
    });

    testWidgets('invokes onPressed when tapped', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(label: 'Tap me', onPressed: () => pressed++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      expect(pressed, 1);
    });

    testWidgets('shows a loader and disables tap when loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Tap me',
              onPressed: null,
              isLoading: true,
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Tap me'), findsNothing);
    });
  });
}
