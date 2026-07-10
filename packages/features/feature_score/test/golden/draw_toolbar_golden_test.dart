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

Future<void> _pump(
  WidgetTester tester, {
  bool eraserActive = false,
  bool canUndo = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: DrawToolbar(
            penColor: const Color(0xFF0072B2),
            eraserActive: eraserActive,
            canUndo: canUndo,
            onEraserToggled: () {},
            onUndo: () {},
            onDone: () {},
          ),
        ),
      ),
    ),
  );
  // Flushes `AppTextButton`'s `flutter_animate` fade-in delayed-start
  // future (see `score_viewer_screen_golden_test.dart`'s failure-state note
  // for the same pattern) — a zero-duration pump alone leaves it pending,
  // which trips the test binding's "no pending timers" invariant at
  // teardown now that this toolbar includes a "Done" `AppTextButton`.
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  group('DrawToolbar goldens', () {
    testWidgets('pen active, shows the participant ink colour', (tester) async {
      await _pump(tester);
      await expectLater(
        find.byType(DrawToolbar),
        matchesGoldenFile('goldens/draw_toolbar_pen.png'),
      );
    });

    testWidgets('eraser active', (tester) async {
      await _pump(tester, eraserActive: true, canUndo: false);
      await expectLater(
        find.byType(DrawToolbar),
        matchesGoldenFile('goldens/draw_toolbar_eraser.png'),
      );
    });
  });
}
