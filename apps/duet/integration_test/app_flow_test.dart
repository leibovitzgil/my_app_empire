// End-to-end core-loop flow for Duet, driving the *real* `ScoreViewerScreen`
// (including genuine drag gestures for drawing/region-select) via a real
// device/engine — `flutter test integration_test/app_flow_test.dart` needs
// a device (see the `flutter-e2e` skill), so this can't run in this
// sandbox; use `flutter drive` for screenshots. The import portion is
// shared with the headless mirror at `../test/duet_flow_test.dart` via
// `runDuetImportFlow` (see `duet_flow_harness.dart` for why the two diverge
// after that for the Score Viewer portion).
import 'package:core_utils/core_utils.dart';
import 'package:feature_score/feature_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pieces/pieces.dart';

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
          currentUserId: teacherId,
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

      // 2. Teacher draws a stroke with a real drag gesture; ink lands on
      // the teacher's own layer only.
      final canvasCenter = tester.getCenter(find.byType(InteractiveViewer));

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();
      expect(bloc.state.mode, ScoreMode.draw);

      await _dragIncrementally(tester, canvasCenter, const Offset(-48, -36));
      await tester.pumpAndSettle();
      expect(bloc.state.teacherStrokes, hasLength(1));
      expect(bloc.state.teacherStrokes.single.authorId, teacherId);
      expect(bloc.state.studentStrokes, isEmpty);
      await shot('04_stroke_drawn');

      // Turn drawing mode back off before region-select (mutually
      // exclusive).
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();

      // 3. Region-select a passage and record an audio note on it.
      await tester.tap(find.byIcon(Icons.crop_free));
      await tester.pump();
      expect(bloc.state.mode, ScoreMode.regionSelect);

      await _dragIncrementally(
        tester,
        canvasCenter - const Offset(60, 60),
        const Offset(120, 100),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record audio note'));
      await tester.pumpAndSettle();
      await shot('05_record_sheet');

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      expect(find.byIcon(Icons.stop), findsOneWidget);

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();
      expect(find.text('Save'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(bloc.state.notes, hasLength(1));
      final recordedNote = bloc.state.notes.single;
      expect(recordedNote.authorId, teacherId);
      expect(recordedNote.region.left, inInclusiveRange(0.0, 1.0));
      expect(recordedNote.region.width, greaterThan(0));
      await shot('06_audio_note_saved');

      // 4. Layer toggles are independent and immediate: toggling teacher
      // ink off leaves student ink and audio pins untouched.
      await tester.tap(find.text('Teacher'));
      await tester.pump();
      expect(bloc.state.teacherInkVisible, isFalse);
      expect(bloc.state.studentInkVisible, isTrue);
      expect(bloc.state.audioPinsVisible, isTrue);
      await shot('07_teacher_layer_hidden');

      // 5. Clean workspace hides every layer regardless of its own flag...
      await tester.tap(find.byIcon(Icons.layers_outlined));
      await tester.pump();
      expect(bloc.state.cleanWorkspace, isTrue);
      expect(bloc.state.effectiveTeacherInkVisible, isFalse);
      expect(bloc.state.effectiveStudentInkVisible, isFalse);
      expect(bloc.state.effectiveAudioPinsVisible, isFalse);
      await shot('08_clean_workspace');

      // ...a layer toggled *while* masked still updates its underlying
      // flag...
      await tester.tap(find.text('Audio pins'));
      await tester.pump();
      expect(bloc.state.audioPinsVisible, isFalse);
      expect(bloc.state.effectiveAudioPinsVisible, isFalse); // still masked

      // ...and turning clean workspace off restores the *exact* prior
      // per-layer state — teacher still off, student still on, audio pins
      // now off (the change made while masked) — never a reset to some
      // default.
      await tester.tap(find.byIcon(Icons.layers_clear_outlined));
      await tester.pump();
      expect(bloc.state.cleanWorkspace, isFalse);
      expect(bloc.state.teacherInkVisible, isFalse);
      expect(bloc.state.studentInkVisible, isTrue);
      expect(bloc.state.audioPinsVisible, isFalse);
      await shot('09_clean_workspace_restored');

      // 6. Close the piece and reopen it: the stroke and the audio note (at
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

      expect(reopened.state.teacherStrokes, hasLength(1));
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
