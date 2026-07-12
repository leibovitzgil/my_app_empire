import 'package:duet/features/score/score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {required ScoreMode mode}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ModeSegmentedControl(mode: mode, onModeSelected: (_) {}),
      ),
    ),
  );
}

void main() {
  group('ModeSegmentedControl', () {
    testWidgets('shows the three mode labels', (tester) async {
      await _pump(tester, mode: ScoreMode.view);

      expect(find.text('View'), findsOneWidget);
      expect(find.text('Draw'), findsOneWidget);
      expect(find.text('Passage'), findsOneWidget);
    });

    testWidgets('tapping Draw dispatches ScoreMode.draw', (tester) async {
      ScoreMode? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModeSegmentedControl(
              mode: ScoreMode.view,
              onModeSelected: (mode) => selected = mode,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Draw'));
      expect(selected, ScoreMode.draw);
    });

    testWidgets('tapping Passage dispatches ScoreMode.regionSelect', (
      tester,
    ) async {
      ScoreMode? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModeSegmentedControl(
              mode: ScoreMode.view,
              onModeSelected: (mode) => selected = mode,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Passage'));
      expect(selected, ScoreMode.regionSelect);
    });

    testWidgets('marks the active mode as selected in semantics', (
      tester,
    ) async {
      await _pump(tester, mode: ScoreMode.draw);

      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Draw mode, selected'), findsOneWidget);
      expect(find.bySemanticsLabel('View mode'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('every segment meets the 48x48 minimum tap target', (
      tester,
    ) async {
      await _pump(tester, mode: ScoreMode.view);

      final segments = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox &&
            widget.constraints.minWidth == 48 &&
            widget.constraints.minHeight == 48,
      );
      expect(segments, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        final size = tester.getSize(segments.at(i));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });
  });
}
