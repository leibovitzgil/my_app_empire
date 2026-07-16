@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:duet/features/score/score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes. The reader is unconditionally
// dark (see `score_viewer_screen.dart`), so every feature_score golden uses
// the dark test theme.
final ThemeData _theme = AppTheme.testTheme(brightness: Brightness.dark);

const List<ParticipantLayer> _layers = [
  ParticipantLayer(
    ownerId: 'owner',
    label: 'Ms. Rivera',
    colorId: 'p0',
    isOwn: true,
    visible: true,
    strokes: [],
  ),
  ParticipantLayer(
    ownerId: 'c1',
    label: 'Maya K.',
    colorId: 'p1',
    isOwn: false,
    visible: true,
    hasNewInk: true,
    strokes: [],
  ),
  ParticipantLayer(
    ownerId: 'c2',
    label: 'Tomer R.',
    colorId: 'p2',
    isOwn: false,
    visible: false,
    strokes: [],
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  bool cleanWorkspace = false,
  VoidCallback? onNudge,
  String? nudgeTargetName,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 600,
          child: LayersPanel(
            layers: _layers,
            audioPinsVisible: true,
            audioPinCountOnPage: 2,
            cleanWorkspace: cleanWorkspace,
            onInkToggle: (_) {},
            onAudioToggle: () {},
            onCleanWorkspaceToggle: () {},
            onClose: () {},
            onNudge: onNudge,
            nudgeTargetName: nudgeTargetName,
          ),
        ),
      ),
    ),
  );
  // Flushes `AppTextButton`'s `flutter_animate` fade-in delayed-start
  // future (see `score_viewer_screen_golden_test.dart`'s failure-state note
  // for the same pattern) — a zero-duration pump alone leaves it pending,
  // which trips the test binding's "no pending timers" invariant at
  // teardown once the "Nudge" button is on screen.
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  group('LayersPanel goldens', () {
    testWidgets('collaborators, one hidden, nudge prompt', (tester) async {
      await _pump(tester, onNudge: () {}, nudgeTargetName: 'Maya K.');
      await expectLater(
        find.byType(LayersPanel),
        matchesGoldenFile('goldens/layers_panel_nudge.png'),
      );
    });

    testWidgets('clean workspace on, no nudge prompt', (
      tester,
    ) async {
      await _pump(tester, cleanWorkspace: true);
      await expectLater(
        find.byType(LayersPanel),
        matchesGoldenFile('goldens/layers_panel_clean_workspace.png'),
      );
    });
  });
}
