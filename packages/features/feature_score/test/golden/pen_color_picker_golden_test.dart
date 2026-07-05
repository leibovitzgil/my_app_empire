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
  int selectedColorId = 0,
  bool eraserActive = false,
  bool canUndo = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: PenColorPicker(
            selectedColorId: selectedColorId,
            eraserActive: eraserActive,
            canUndo: canUndo,
            onColorSelected: (_) {},
            onEraserToggled: () {},
            onUndo: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('PenColorPicker goldens', () {
    testWidgets('pen selected, nothing to undo', (tester) async {
      await _pump(tester);
      await expectLater(
        find.byType(PenColorPicker),
        matchesGoldenFile('goldens/pen_color_picker_pen.png'),
      );
    });

    testWidgets('eraser active, undo available', (tester) async {
      await _pump(tester, eraserActive: true, canUndo: true);
      await expectLater(
        find.byType(PenColorPicker),
        matchesGoldenFile('goldens/pen_color_picker_eraser.png'),
      );
    });
  });
}
