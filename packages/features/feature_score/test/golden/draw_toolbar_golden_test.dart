@Tags(['golden'])
library;

import 'package:feature_score/feature_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A network-free theme (AppTheme pulls google_fonts, which fetches at
// runtime and fails in tests).
final _theme = ThemeData(useMaterial3: true);

Future<void> _pump(
  WidgetTester tester, {
  bool eraserActive = false,
  bool canUndo = true,
}) {
  return tester.pumpWidget(
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
          ),
        ),
      ),
    ),
  );
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
