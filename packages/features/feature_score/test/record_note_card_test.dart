import 'dart:async';

import 'package:audio/audio.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_score/feature_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAudioRecorderService implements AudioRecorderService {
  bool permissionDenied = false;
  String stopPath = '/tmp/note.m4a';
  int startCalls = 0;
  int stopCalls = 0;

  final _elapsedController = StreamController<Duration>.broadcast();

  @override
  Future<Result<void>> start(String outputPath, {int maxMillis = 60000}) async {
    startCalls++;
    if (permissionDenied) {
      return const ResultFailure<void>(
        AudioRecordException('Microphone permission denied'),
      );
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<String>> stop() async {
    stopCalls++;
    return Success<String>(stopPath);
  }

  @override
  Stream<Duration> get elapsed => _elapsedController.stream;

  void emitElapsed(Duration duration) => _elapsedController.add(duration);
}

class _FakeAudioPlayerService implements AudioPlayerService {
  final List<String> playedPaths = [];
  int stopCalls = 0;

  final _progressController = StreamController<PlaybackProgress>.broadcast();

  @override
  Future<Result<void>> play(String path) async {
    playedPaths.add(path);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> stop() async {
    stopCalls++;
    return const Success<void>(null);
  }

  @override
  Stream<PlaybackProgress> get progress => _progressController.stream;
}

/// Everything a test needs, constructed *inside* the `testWidgets` body so
/// each test's cubits, controllers, and counters live and die inside its
/// own fake-async zone (see `record_audio_cubit_test.dart` for the class of
/// hang that out-of-zone stream controllers cause).
class _Fixture {
  _Fixture()
    : recorder = _FakeAudioRecorderService(),
      player = _FakeAudioPlayerService() {
    recordCubit = RecordAudioCubit(recorder: recorder);
    playbackCubit = AudioPlaybackCubit(player: player);
  }

  final _FakeAudioRecorderService recorder;
  final _FakeAudioPlayerService player;
  late final RecordAudioCubit recordCubit;
  late final AudioPlaybackCubit playbackCubit;
  final saved = <(String, Duration)>[];
  int dismissed = 0;
}

Future<_Fixture> _pumpCard(
  WidgetTester tester, {
  bool permissionDenied = false,
}) async {
  final fixture = _Fixture();
  fixture.recorder.permissionDenied = permissionDenied;
  addTearDown(() async {
    await fixture.recordCubit.close();
    await fixture.playbackCubit.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<RecordAudioCubit>.value(value: fixture.recordCubit),
            BlocProvider<AudioPlaybackCubit>.value(
              value: fixture.playbackCubit,
            ),
          ],
          child: Center(
            child: SizedBox(
              width: 540,
              child: RecordNoteCard(
                regionLabel: 'Page 2 · selected passage',
                outputPathBuilder: () => '/tmp/out.m4a',
                onSave: (path, elapsed) => fixture.saved.add((path, elapsed)),
                onDismiss: () => fixture.dismissed++,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // First pump mounts; the post-frame callback auto-starts recording,
  // which resolves over a microtask.
  await tester.pump();
  await tester.pump();
  return fixture;
}

void main() {
  group('RecordNoteCard', () {
    testWidgets('auto-starts recording on mount and ticks the timer', (
      tester,
    ) async {
      final fixture = await _pumpCard(tester);

      expect(fixture.recorder.startCalls, 1);
      expect(fixture.recordCubit.state.status, RecordAudioStatus.recording);
      expect(find.text('Audio note'), findsOneWidget);
      expect(find.text('Page 2 · selected passage'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget);

      fixture.recorder.emitElapsed(const Duration(seconds: 7));
      await tester.pump();
      expect(find.text('0:07'), findsOneWidget);
    });

    testWidgets('stop moves to review with listen-back, save and discard', (
      tester,
    ) async {
      final fixture = await _pumpCard(tester);
      fixture.recorder.emitElapsed(const Duration(seconds: 12));
      await tester.pump();

      await tester.tap(find.text('Stop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Recorded 12s — keep it?'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('Save note'), findsOneWidget);

      // Listen back before deciding: plays the recorded file under the
      // preview id, and tapping again stops it.
      await tester.tap(find.bySemanticsLabel('Listen to your recording'));
      await tester.pump();
      expect(fixture.player.playedPaths, ['/tmp/note.m4a']);
      expect(
        fixture.playbackCubit.state.isPlaying(RecordNoteCard.previewNoteId),
        isTrue,
      );

      await tester.tap(find.bySemanticsLabel('Stop listening'));
      await tester.pump();
      expect(
        fixture.playbackCubit.state.isPlaying(RecordNoteCard.previewNoteId),
        isFalse,
      );
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('save hands the recording to onSave', (tester) async {
      final fixture = await _pumpCard(tester);
      fixture.recorder.emitElapsed(const Duration(seconds: 9));
      await tester.pump();
      await tester.tap(find.text('Stop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Save note'));
      await tester.pump();

      expect(fixture.saved, [('/tmp/note.m4a', const Duration(seconds: 9))]);
      expect(fixture.recordCubit.state.status, RecordAudioStatus.idle);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('discard drops the recording and dismisses', (tester) async {
      final fixture = await _pumpCard(tester);
      await tester.tap(find.text('Stop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Discard'));
      await tester.pump();

      expect(fixture.saved, isEmpty);
      expect(fixture.dismissed, 1);
      expect(fixture.recordCubit.state.status, RecordAudioStatus.idle);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('a denied microphone lands in the error state with retry', (
      tester,
    ) async {
      final fixture = await _pumpCard(tester, permissionDenied: true);

      expect(find.text("Couldn't record"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      fixture.recorder.permissionDenied = false;
      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(fixture.recorder.startCalls, 2);
      expect(fixture.recordCubit.state.status, RecordAudioStatus.recording);
      expect(find.text('Stop'), findsOneWidget);
    });

    testWidgets('error state Cancel dismisses the flow', (tester) async {
      final fixture = await _pumpCard(tester, permissionDenied: true);

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(fixture.dismissed, 1);
    });

    testWidgets('unmounting mid-recording cancels so the mic never stays '
        'hot', (tester) async {
      final fixture = await _pumpCard(tester);
      expect(fixture.recordCubit.state.status, RecordAudioStatus.recording);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      expect(fixture.recorder.stopCalls, 1);
      expect(fixture.recordCubit.state.status, RecordAudioStatus.idle);
    });
  });
}
