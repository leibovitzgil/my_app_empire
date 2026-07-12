@Tags(['golden'])
library;

import 'dart:async';

import 'package:audio/audio.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/features/score/score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes. The reader is unconditionally
// dark (see `score_viewer_screen.dart`), so every feature_score golden uses
// the dark test theme.
final ThemeData _theme = AppTheme.testTheme(brightness: Brightness.dark);

class _FakeAudioRecorderService implements AudioRecorderService {
  bool permissionDenied = false;

  final _elapsedController = StreamController<Duration>.broadcast();

  @override
  Future<Result<void>> start(String outputPath, {int maxMillis = 60000}) async {
    if (permissionDenied) {
      return const ResultFailure<void>(
        AudioRecordException('Microphone permission denied'),
      );
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<String>> stop() async => const Success<String>('/tmp/n.m4a');

  @override
  Stream<Duration> get elapsed => _elapsedController.stream;

  void emitElapsed(Duration duration) => _elapsedController.add(duration);
}

class _FakeAudioPlayerService implements AudioPlayerService {
  final _progressController = StreamController<PlaybackProgress>.broadcast();

  @override
  Future<Result<void>> play(String path) async => const Success<void>(null);

  @override
  Future<Result<void>> stop() async => const Success<void>(null);

  @override
  Stream<PlaybackProgress> get progress => _progressController.stream;
}

void main() {
  group('RecordNoteCard goldens', () {
    Future<_FakeAudioRecorderService> pumpCard(
      WidgetTester tester, {
      bool permissionDenied = false,
    }) async {
      final recorder = _FakeAudioRecorderService()
        ..permissionDenied = permissionDenied;
      final recordCubit = RecordAudioCubit(recorder: recorder);
      final playbackCubit = AudioPlaybackCubit(
        player: _FakeAudioPlayerService(),
      );
      addTearDown(() async {
        await recordCubit.close();
        await playbackCubit.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<RecordAudioCubit>.value(value: recordCubit),
                BlocProvider<AudioPlaybackCubit>.value(value: playbackCubit),
              ],
              child: Center(
                child: SizedBox(
                  width: 540,
                  child: RecordNoteCard(
                    regionLabel: 'Page 2 · selected passage',
                    outputPathBuilder: () => '/tmp/out.m4a',
                    onSave: (_, _) {},
                    onDismiss: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // Mount, auto-start, and land on a deterministic animation frame (the
      // pulse controller is time-driven, so fixed pumps give a fixed frame).
      await tester.pump();
      await tester.pump();
      return recorder;
    }

    testWidgets('recording', (tester) async {
      final recorder = await pumpCard(tester);
      recorder.emitElapsed(const Duration(seconds: 7));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await expectLater(
        find.byType(RecordNoteCard),
        matchesGoldenFile('goldens/record_note_card_recording.png'),
      );
    });

    testWidgets('reviewing', (tester) async {
      final recorder = await pumpCard(tester);
      recorder.emitElapsed(const Duration(seconds: 12));
      await tester.pump();
      await tester.tap(find.text('Stop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(RecordNoteCard),
        matchesGoldenFile('goldens/record_note_card_reviewing.png'),
      );
    });

    testWidgets('error', (tester) async {
      await pumpCard(tester, permissionDenied: true);
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(RecordNoteCard),
        matchesGoldenFile('goldens/record_note_card_error.png'),
      );
    });
  });
}
