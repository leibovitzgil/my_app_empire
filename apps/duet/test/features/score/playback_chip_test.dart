import 'package:duet/features/score/score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {double? progress}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PlaybackChip(
          authorInitials: 'MK',
          authorColor: Colors.purple,
          authorName: 'Maya',
          positionLabel: '0:12',
          durationLabel: '0:19',
          progress: progress,
        ),
      ),
    ),
  );
}

void main() {
  group('PlaybackChip', () {
    testWidgets("shows the author's note label and mm:ss / mm:ss", (
      tester,
    ) async {
      await _pump(tester, progress: 0.6);

      expect(find.text("Maya's note"), findsOneWidget);
      expect(find.text('0:12 / 0:19'), findsOneWidget);
    });

    testWidgets('renders a real LinearProgressIndicator, not a waveform', (
      tester,
    ) async {
      await _pump(tester, progress: 0.6);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.6);
    });

    testWidgets('is a live region announcing the current position', (
      tester,
    ) async {
      await _pump(tester, progress: 0.6);

      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel("Maya's note playing, 0:12 of 0:19"),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('tolerates a null (indeterminate) progress', (tester) async {
      await _pump(tester);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, isNull);
    });
  });
}
