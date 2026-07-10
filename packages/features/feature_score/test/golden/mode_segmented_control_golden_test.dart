@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:feature_score/feature_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes. The reader is unconditionally
// dark (see `score_viewer_screen.dart`), so every feature_score golden uses
// the dark test theme.
final ThemeData _theme = AppTheme.testTheme(brightness: Brightness.dark);

Future<void> _pump(WidgetTester tester, {required ScoreMode mode}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: Scaffold(
        body: Center(
          child: ModeSegmentedControl(mode: mode, onModeSelected: (_) {}),
        ),
      ),
    ),
  );
}

void main() {
  group('ModeSegmentedControl goldens', () {
    testWidgets('view selected', (tester) async {
      await _pump(tester, mode: ScoreMode.view);
      await expectLater(
        find.byType(ModeSegmentedControl),
        matchesGoldenFile('goldens/mode_segmented_control_view.png'),
      );
    });

    testWidgets('draw selected', (tester) async {
      await _pump(tester, mode: ScoreMode.draw);
      await expectLater(
        find.byType(ModeSegmentedControl),
        matchesGoldenFile('goldens/mode_segmented_control_draw.png'),
      );
    });

    testWidgets('passage selected', (tester) async {
      await _pump(tester, mode: ScoreMode.regionSelect);
      await expectLater(
        find.byType(ModeSegmentedControl),
        matchesGoldenFile('goldens/mode_segmented_control_passage.png'),
      );
    });
  });
}
