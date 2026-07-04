import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required void Function(Future<bool>) onOpened,
  bool isDestructive = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () => onOpened(
              confirmDialog(
                context,
                title: 'Delete item?',
                message: 'This cannot be undone.',
                isDestructive: isDestructive,
              ),
            ),
            child: const Text('Open'),
          );
        },
      ),
    ),
  );
}

void main() {
  group('confirmDialog', () {
    testWidgets('resolves to true when Confirm is tapped', (tester) async {
      late Future<bool> result;
      await tester.pumpWidget(_harness(onOpened: (f) => result = f));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(await result, isTrue);
    });

    testWidgets('resolves to false when Cancel is tapped', (tester) async {
      late Future<bool> result;
      await tester.pumpWidget(_harness(onOpened: (f) => result = f));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await result, isFalse);
    });

    testWidgets('resolves to false when the barrier is dismissed', (
      tester,
    ) async {
      late Future<bool> result;
      await tester.pumpWidget(_harness(onOpened: (f) => result = f));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Tap far outside the dialog to hit the modal barrier.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(await result, isFalse);
    });

    testWidgets('starts focused on Cancel when isDestructive is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(onOpened: (_) {}, isDestructive: true),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final cancelContext = tester.element(find.text('Cancel'));
      expect(Focus.of(cancelContext).hasFocus, isTrue);
    });

    testWidgets('does not autofocus Cancel when isDestructive is false', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(onOpened: (_) {}));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final cancelContext = tester.element(find.text('Cancel'));
      expect(Focus.of(cancelContext).hasFocus, isFalse);
    });
  });
}
