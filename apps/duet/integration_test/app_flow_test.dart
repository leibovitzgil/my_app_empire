// End-to-end core-loop flow for Duet, driving the *real* `ScoreViewerScreen`
// (including genuine drag gestures for drawing/region-select) via a real
// device/engine — `flutter test integration_test/app_flow_test.dart` needs
// a device (see the `flutter-e2e` skill), so this can't run in this
// sandbox; use `flutter drive` for screenshots. The import portion is
// shared with the headless mirror at `../test/duet_flow_test.dart` via
// `runDuetImportFlow` (see `duet_flow_harness.dart` for why the two diverge
// after that for the Score Viewer portion).
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/score/score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/duet_flow_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(String name) async {
    try {
      await binding.takeScreenshot(name);
    } on Object {
      // No driver attached — skip.
    }
  }

  testWidgets(
    'import -> annotate -> record audio note -> toggle layers -> '
    'clean workspace -> close/reopen',
    (tester) async {
      final imported = await runDuetImportFlow(tester, shot: shot);
      final pieceRepository = imported.pieceRepository;
      final annotationRepository = imported.annotationRepository;
      final audioAssetStore = imported.audioAssetStore;
      final renderService = imported.renderService;
      final navigatorKey = imported.navigatorKey;
      var recordingSeq = 0;

      ScoreBloc? scoreBloc;
      Widget buildScoreViewer(Piece piece) {
        final bloc = ScoreBloc(
          pieceRepository: pieceRepository,
          annotationRepository: annotationRepository,
          currentUserId: ownerId,
        )..add(ScoreOpened(piece.id));
        scoreBloc = bloc;
        return BlocProvider<ScoreBloc>.value(
          value: bloc,
          child: ScoreViewerScreen(
            renderService: renderService,
            recorderService: FakeAudioRecorderService(),
            playerService: FakeAudioPlayerService(),
            recordingPathBuilder: () => 'rec_${recordingSeq++}.m4a',
            audioAssetStore: audioAssetStore,
          ),
        );
      }

      await navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => buildScoreViewer(imported.piece),
        ),
      );
      await tester.pumpAndSettle();
      final bloc = scoreBloc!;
      expect(bloc.state.status, ScoreStatus.ready);
      await shot('03_score_viewer_empty');

      // 2. Owner draws a stroke with a real drag gesture; ink lands on
      // the owner's own layer only.
      final canvasCenter = tester.getCenter(find.byType(InteractiveViewer));

      await tester.tap(find.text('Draw'));
      await tester.pump();
      expect(bloc.state.mode, ScoreMode.draw);

      await _dragIncrementally(tester, canvasCenter, const Offset(-48, -36));
      await tester.pumpAndSettle();
      // On a sheet with no collaborators there is exactly one participant
      // layer — the owner's — and the stroke lands on it.
      expect(bloc.state.layers, hasLength(1));
      expect(bloc.state.ownLayer!.strokes, hasLength(1));
      expect(bloc.state.ownLayer!.strokes.single.authorId, ownerId);
      await shot('04_stroke_drawn');

      // 3. Region-select a passage and record an audio note on it. The mode
      // segmented control's segments are mutually exclusive by construction
      // (unlike the old FAB pair, which toggled relative to the current
      // mode), so tapping "Passage" directly from draw mode switches with no
      // separate "turn off draw" step needed.
      await tester.tap(find.text('Passage'));
      await tester.pump();
      expect(bloc.state.mode, ScoreMode.regionSelect);

      await _dragIncrementally(
        tester,
        canvasCenter - const Offset(60, 60),
        const Offset(120, 100),
      );
      await tester.pumpAndSettle();
      // The anchored popover (≥600dp) and the bottom-sheet fallback
      // (<600dp) share this exact copy, so this finder works either way.
      await tester.tap(find.text('Record an audio note'));
      // Bounded pumps, not pumpAndSettle: the record card auto-starts
      // recording on mount, and its pulsing mic disc animates for as long
      // as the recording runs — pumpAndSettle would never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await shot('05_record_card');

      // Recording is already live (no separate mic tap); stop it, review,
      // and keep it.
      expect(find.text('Stop'), findsOneWidget);
      await tester.tap(find.text('Stop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Save note'), findsOneWidget);

      await tester.tap(find.text('Save note'));
      await tester.pumpAndSettle();

      expect(bloc.state.notes, hasLength(1));
      final recordedNote = bloc.state.notes.single;
      expect(recordedNote.authorId, ownerId);
      expect(recordedNote.region.left, inInclusiveRange(0.0, 1.0));
      expect(recordedNote.region.width, greaterThan(0));
      await shot('06_audio_note_saved');

      // 4. Layer toggles are independent and immediate: toggling the owner's
      // ink layer off (their row carries the "(yours)" indicator) leaves
      // audio pins untouched. The Layers panel lives behind a "Layers"
      // button at some widths (it's docked inline on wide/tablet layouts,
      // otherwise reached via an endDrawer or bottom sheet) — open it first
      // if that button is present; a no-op when already docked.
      await _ensureLayersPanelOpen(tester);
      await tester.tap(find.bySemanticsLabel(RegExp(r'layer \(yours\)')));
      await tester.pump();
      expect(bloc.state.ownLayer!.visible, isFalse);
      expect(bloc.state.audioPinsVisible, isTrue);
      await shot('07_own_layer_hidden');

      // 5. Clean workspace hides every layer regardless of its own flag...
      // (the Layers panel's "Clean workspace" `Switch` replaces the old app
      // bar icon toggle; it's the only `Switch` on this screen).
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(bloc.state.cleanWorkspace, isTrue);
      for (final layer in bloc.state.layers) {
        expect(bloc.state.effectiveInkVisible(layer), isFalse);
      }
      expect(bloc.state.effectiveAudioPinsVisible, isFalse);
      await shot('08_clean_workspace');

      // ...a layer toggled *while* masked still updates its underlying
      // flag...
      await tester.tap(find.text('Audio pins'));
      await tester.pump();
      expect(bloc.state.audioPinsVisible, isFalse);
      expect(bloc.state.effectiveAudioPinsVisible, isFalse); // still masked

      // ...and turning clean workspace off restores the *exact* prior
      // per-layer state — the owner's ink still off, audio pins now off (the
      // change made while masked) — never a reset to some default.
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(bloc.state.cleanWorkspace, isFalse);
      expect(bloc.state.ownLayer!.visible, isFalse);
      expect(bloc.state.audioPinsVisible, isFalse);
      await shot('09_clean_workspace_restored');
      // Closes the endDrawer/bottom sheet, if that's how the panel was
      // shown, so the next `pop()` closes the Score Viewer itself rather
      // than a still-open modal.
      await _ensureLayersPanelClosed(tester);

      // 6. Close the sheet and reopen it: the stroke and the audio note (at
      // the same fractional position) both survive, via a brand-new
      // `ScoreBloc` reading the same repository-backed annotations.
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      final pieceResult = await pieceRepository.getPiece(bloc.state.piece!.id);
      final piece = (pieceResult as Success<Piece>).value;
      await navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => buildScoreViewer(piece)),
      );
      await tester.pumpAndSettle();
      final reopened = scoreBloc!;

      expect(reopened.state.ownLayer!.strokes, hasLength(1));
      expect(reopened.state.notes, hasLength(1));
      expect(reopened.state.notes.single.region, recordedNote.region);
      await shot('10_reopened');
    },
  );
}

/// Drags from [start] by [totalOffset] in several incremental steps with a
/// pump between each, rather than one large jump.
///
/// This canvas nests a plain `GestureDetector` (the draw/region-select
/// layer) inside an `InteractiveViewer` (for pan/zoom) — two competing
/// pan-family recognizers in the same gesture arena; stepping the drag with
/// a pump in between each move (much closer to a real touch drag) reliably
/// resolves the arena in the inner `GestureDetector`'s favor.
Future<void> _dragIncrementally(
  WidgetTester tester,
  Offset start,
  Offset totalOffset, {
  int steps = 6,
}) async {
  final gesture = await tester.startGesture(start);
  final step = totalOffset / steps.toDouble();
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(step);
    await tester.pump(const Duration(milliseconds: 20));
  }
  await gesture.up();
}

/// Opens the Score Viewer's Layers panel if it isn't already showing.
///
/// The panel docks inline on wide/tablet layouts (no button — this is a
/// no-op there), otherwise it's reached via a "Layers" button that opens an
/// `endDrawer` or a bottom sheet depending on width. This device-only test
/// can't assume a specific window size, so it checks for the button rather
/// than hardcoding one path.
Future<void> _ensureLayersPanelOpen(WidgetTester tester) async {
  final layersButton = find.bySemanticsLabel('Layers');
  if (layersButton.evaluate().isNotEmpty) {
    await tester.tap(layersButton);
    await tester.pumpAndSettle();
  }
}

/// Closes the Layers panel's `endDrawer`/bottom sheet, if that's how it was
/// shown (see [_ensureLayersPanelOpen]) — a no-op when the panel is docked
/// inline, so a caller's next `Navigator.pop()` closes the Score Viewer
/// itself rather than a still-open modal.
Future<void> _ensureLayersPanelClosed(WidgetTester tester) async {
  final closeButton = find.bySemanticsLabel('Close layers panel');
  if (closeButton.evaluate().isNotEmpty) {
    await tester.tap(closeButton);
    await tester.pumpAndSettle();
  }
}
