@Tags(['golden'])
library;

import 'package:feature_score/feature_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pieces/pieces.dart';

// A network-free theme (AppTheme pulls google_fonts, which fetches at
// runtime and fails in tests).
final _theme = ThemeData(useMaterial3: true);

Future<void> _pump(
  WidgetTester tester, {
  required PieceRole role,
  bool teacherInkVisible = true,
  bool studentInkVisible = true,
  bool audioPinsVisible = true,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: Scaffold(
        body: LayerToggleBar(
          currentRole: role,
          teacherInkVisible: teacherInkVisible,
          studentInkVisible: studentInkVisible,
          audioPinsVisible: audioPinsVisible,
          onToggle: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('LayerToggleBar goldens', () {
    testWidgets('teacher, all visible', (tester) async {
      await _pump(tester, role: PieceRole.teacher);
      await expectLater(
        find.byType(LayerToggleBar),
        matchesGoldenFile('goldens/layer_toggle_bar_teacher.png'),
      );
    });

    testWidgets('student, teacher ink hidden', (tester) async {
      await _pump(
        tester,
        role: PieceRole.student,
        teacherInkVisible: false,
      );
      await expectLater(
        find.byType(LayerToggleBar),
        matchesGoldenFile('goldens/layer_toggle_bar_student.png'),
      );
    });
  });
}
