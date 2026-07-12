import 'package:duet/features/score/score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onPractice,
  VoidCallback? onRecord,
  VoidCallback? onCancel,
  String title = 'This passage',
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: PassagePopover(
            onPractice: onPractice ?? () {},
            onRecord: onRecord ?? () {},
            onCancel: onCancel ?? () {},
            title: title,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('PassagePopover', () {
    testWidgets('shows the honest header, never a fabricated location', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('THIS PASSAGE'), findsOneWidget);
      expect(find.textContaining('System'), findsNothing);
      expect(find.textContaining('Bars'), findsNothing);
    });

    testWidgets('lists Practice before Record, then Cancel', (tester) async {
      await _pump(tester);

      final practice = tester.getTopLeft(find.text('Practice this passage'));
      final record = tester.getTopLeft(find.text('Record an audio note'));
      final cancel = tester.getTopLeft(find.text('Cancel'));
      expect(practice.dy, lessThan(record.dy));
      expect(record.dy, lessThan(cancel.dy));
    });

    testWidgets('tapping Practice invokes onPractice', (tester) async {
      var tapped = false;
      await _pump(tester, onPractice: () => tapped = true);

      await tester.tap(find.text('Practice this passage'));
      expect(tapped, isTrue);
    });

    testWidgets('tapping Record invokes onRecord', (tester) async {
      var tapped = false;
      await _pump(tester, onRecord: () => tapped = true);

      await tester.tap(find.text('Record an audio note'));
      expect(tapped, isTrue);
    });

    testWidgets('tapping Cancel invokes onCancel', (tester) async {
      var tapped = false;
      await _pump(tester, onCancel: () => tapped = true);

      await tester.tap(find.text('Cancel'));
      expect(tapped, isTrue);
    });

    testWidgets('carries over rich semantics for record and cancel', (
      tester,
    ) async {
      await _pump(tester);

      expect(
        find.bySemanticsLabel('Record an audio note for this passage'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Cancel region selection'),
        findsOneWidget,
      );
    });

    testWidgets('every action meets the 48-height minimum tap target', (
      tester,
    ) async {
      await _pump(tester);

      final boxes = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox && widget.constraints.minHeight == 48,
      );
      expect(boxes, findsNWidgets(3));
    });
  });
}
