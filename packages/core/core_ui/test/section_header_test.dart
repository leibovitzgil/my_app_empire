import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SectionHeader', () {
    testWidgets('renders its label in the primary color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SectionHeader('Profile')),
        ),
      );

      expect(find.text('Profile'), findsOneWidget);
      final text = tester.widget<Text>(find.text('Profile'));
      final primary = Theme.of(
        tester.element(find.text('Profile')),
      ).colorScheme.primary;
      expect(text.style?.color, primary);
    });
  });
}
