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

const List<PageInkPresence> _presence = [
  (hasAudio: false, inkColors: [Color(0xFF0072B2)]),
  (hasAudio: true, inkColors: [Color(0xFF0072B2), Color(0xFFD55E00)]),
  (hasAudio: false, inkColors: []),
];

Future<void> _pump(WidgetTester tester, {bool dimmed = false}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: PageThumbnailRail(
            pageCount: 3,
            currentPage: 1,
            presence: _presence,
            onSelectPage: (_) {},
            dimmed: dimmed,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('PageThumbnailRail goldens', () {
    testWidgets('current page 2, ink and audio presence dots', (
      tester,
    ) async {
      await _pump(tester);
      await expectLater(
        find.byType(PageThumbnailRail),
        matchesGoldenFile('goldens/page_thumbnail_rail.png'),
      );
    });

    testWidgets('dimmed (draw mode)', (tester) async {
      await _pump(tester, dimmed: true);
      await expectLater(
        find.byType(PageThumbnailRail),
        matchesGoldenFile('goldens/page_thumbnail_rail_dimmed.png'),
      );
    });
  });
}
