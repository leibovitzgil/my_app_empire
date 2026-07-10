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

const List<AvatarStackPerson> _collaborators = [
  (initials: 'MK', color: Colors.purple),
  (initials: 'TR', color: Colors.orange),
];

Widget _bar({
  ScoreMode mode = ScoreMode.view,
  int currentPage = 1,
  int pageCount = 6,
  ScoreSyncStatus syncStatus = ScoreSyncStatus.notSynced,
  bool cleanWorkspace = false,
}) {
  return MaterialApp(
    theme: _theme,
    home: Scaffold(
      body: ReaderTopBar(
        title: 'Clair de Lune (Four Hands)',
        mode: mode,
        currentPage: currentPage,
        pageCount: pageCount,
        syncStatus: syncStatus,
        cleanWorkspace: cleanWorkspace,
        collaborators: _collaborators,
        collaboratorNames: const ['Maya K.', 'Tomer R.'],
        ownInkColor: const Color(0xFF0072B2),
        onBack: () {},
        onPreviousPage: () {},
        onNextPage: () {},
        onOpenLayers: () {},
        onShare: () async {},
        onImport: () async {},
        onPracticePage: () {},
      ),
    ),
  );
}

void main() {
  group('ReaderTopBar goldens', () {
    testWidgets('view mode, not synced', (tester) async {
      await tester.pumpWidget(_bar());
      await expectLater(
        find.byType(ReaderTopBar),
        matchesGoldenFile('goldens/reader_top_bar_view.png'),
      );
    });

    testWidgets('draw mode, drawing badge', (tester) async {
      await tester.pumpWidget(_bar(mode: ScoreMode.draw));
      await expectLater(
        find.byType(ReaderTopBar),
        matchesGoldenFile('goldens/reader_top_bar_draw.png'),
      );
    });

    testWidgets('passage mode, clean workspace on', (tester) async {
      await tester.pumpWidget(
        _bar(mode: ScoreMode.regionSelect, cleanWorkspace: true),
      );
      await expectLater(
        find.byType(ReaderTopBar),
        matchesGoldenFile('goldens/reader_top_bar_clean_workspace.png'),
      );
    });
  });
}
