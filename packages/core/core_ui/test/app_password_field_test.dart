import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPasswordField', () {
    testWidgets('is obscured by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppPasswordField())),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
    });

    testWidgets('tapping the toggle reveals text without losing focus', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppPasswordField(focusNode: focusNode)),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isFalse);
      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('toggle semantics label reflects the next action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppPasswordField())),
      );

      expect(find.bySemanticsLabel('Show password'), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
      handle.dispose();
    });
  });
}
