@Tags(['golden'])
library;

import 'package:audio/audio.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_score/feature_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';

// A network-free theme (AppTheme pulls google_fonts, which fetches at
// runtime and fails in tests).
final _theme = ThemeData(useMaterial3: true);

class MockPieceRepository extends Mock implements PieceRepository {}

class MockAnnotationRepository extends Mock implements AnnotationRepository {}

class MockPdfRenderService extends Mock implements PdfRenderService {}

class MockAudioRecorderService extends Mock implements AudioRecorderService {}

class MockAudioPlayerService extends Mock implements AudioPlayerService {}

class MockAudioAssetStore extends Mock implements AudioAssetStore {}

/// Neither the loading nor the failure state ever reaches the render/record/
/// playback services, so these are never stubbed — just present to satisfy
/// `ScoreViewerScreen`'s required constructor parameters.
Widget _buildScreen(ScoreBloc bloc) {
  return MaterialApp(
    theme: _theme,
    home: BlocProvider<ScoreBloc>.value(
      value: bloc,
      child: ScoreViewerScreen(
        renderService: MockPdfRenderService(),
        recorderService: MockAudioRecorderService(),
        playerService: MockAudioPlayerService(),
        recordingPathBuilder: () => '/tmp/rec.m4a',
        audioAssetStore: MockAudioAssetStore(),
      ),
    ),
  );
}

void main() {
  group('ScoreViewerScreen goldens', () {
    testWidgets('loading', (tester) async {
      final pieceRepository = MockPieceRepository();
      final annotationRepository = MockAnnotationRepository();
      // `ScoreState.initial` is already `ScoreStatus.loading`; simply never
      // dispatching `ScoreOpened` keeps it there without needing a
      // never-resolving stub (a genuinely-pending `Future` left dangling at
      // test teardown hangs `flutter test` in this environment).
      final bloc = ScoreBloc(
        pieceRepository: pieceRepository,
        annotationRepository: annotationRepository,
        currentUserId: 'teacher-1',
      );
      addTearDown(bloc.close);

      await tester.pumpWidget(_buildScreen(bloc));
      await tester.pump();

      await expectLater(
        find.byType(ScoreViewerScreen),
        matchesGoldenFile('goldens/score_viewer_screen_loading.png'),
      );
    });

    testWidgets('failure', (tester) async {
      final pieceRepository = MockPieceRepository();
      final annotationRepository = MockAnnotationRepository();
      when(() => pieceRepository.getPiece(any())).thenAnswer(
        (_) async => ResultFailure<Piece>(StateError('Unknown piece')),
      );
      final bloc = ScoreBloc(
        pieceRepository: pieceRepository,
        annotationRepository: annotationRepository,
        currentUserId: 'teacher-1',
      )..add(const ScoreOpened('piece-1'));
      addTearDown(bloc.close);

      await tester.pumpWidget(_buildScreen(bloc));
      await tester.pump();
      await tester.pump();
      // Flushes flutter_animate's initial delayed-start future for
      // `PrimaryButton`'s fade-in (see core_ui's `skeleton_test.dart` for the
      // same pattern); a zero-duration pump leaves it pending, which trips
      // the test binding's "no pending timers" invariant at teardown.
      await tester.pump(const Duration(milliseconds: 1));

      await expectLater(
        find.byType(ScoreViewerScreen),
        matchesGoldenFile('goldens/score_viewer_screen_failure.png'),
      );
    });
  });
}
