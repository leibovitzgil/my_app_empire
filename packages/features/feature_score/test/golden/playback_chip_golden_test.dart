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

void main() {
  group('PlaybackChip goldens', () {
    testWidgets('mid-playback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: PlaybackChip(
                authorInitials: 'MK',
                authorColor: Color(0xFF8B5CF6),
                authorName: 'Maya',
                positionLabel: '0:12',
                durationLabel: '0:19',
                progress: 0.6,
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(PlaybackChip),
        matchesGoldenFile('goldens/playback_chip.png'),
      );
    });
  });
}
