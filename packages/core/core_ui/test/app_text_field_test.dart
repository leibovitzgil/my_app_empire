import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTextField', () {
    testWidgets('invokes onChanged as text is entered', (tester) async {
      String? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Email',
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(AppTextField), 'a@b.com');
      expect(changed, 'a@b.com');
    });

    testWidgets('renders errorText when set', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(label: 'Email', errorText: 'Required'),
          ),
        ),
      );

      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('disables input when enabled is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppTextField(label: 'Email', enabled: false)),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });
  });
}
