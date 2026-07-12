import 'dart:async';

import 'package:audio/audio.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/features/score/score.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAudioRecorderService implements AudioRecorderService {
  bool permissionDenied = false;
  bool stopThrows = false;
  String stopPath = '/tmp/note.m4a';
  int startCalls = 0;
  int stopCalls = 0;
  int? lastMaxMillis;

  final _elapsedController = StreamController<Duration>.broadcast();

  @override
  Future<Result<void>> start(String outputPath, {int maxMillis = 60000}) async {
    startCalls++;
    lastMaxMillis = maxMillis;
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
    if (stopThrows) {
      return const ResultFailure<String>(AudioRecordException('boom'));
    }
    return Success<String>(stopPath);
  }

  @override
  Stream<Duration> get elapsed => _elapsedController.stream;

  void emitElapsed(Duration duration) => _elapsedController.add(duration);

  Future<void> dispose() => _elapsedController.close();
}

void main() {
  group('RecordAudioCubit', () {
    late _FakeAudioRecorderService recorder;

    setUp(() {
      recorder = _FakeAudioRecorderService();
    });

    test('initial state is idle', () {
      final cubit = RecordAudioCubit(recorder: recorder);
      expect(cubit.state, const RecordAudioState.idle());
      addTearDown(cubit.close);
    });

    blocTest<RecordAudioCubit, RecordAudioState>(
      'mic-denied surfaces the error state',
      build: () {
        recorder.permissionDenied = true;
        return RecordAudioCubit(recorder: recorder);
      },
      act: (cubit) => cubit.start('/tmp/out.m4a'),
      expect: () => [
        isA<RecordAudioState>().having(
          (s) => s.status,
          'status',
          RecordAudioStatus.error,
        ),
      ],
      verify: (_) {
        expect(recorder.stopCalls, 0);
      },
    );

    blocTest<RecordAudioCubit, RecordAudioState>(
      'start moves to recording, and an explicit stop moves to reviewing',
      build: () => RecordAudioCubit(recorder: recorder),
      act: (cubit) async {
        await cubit.start('/tmp/out.m4a');
        await cubit.stop();
      },
      expect: () => [
        const RecordAudioState.recording(),
        isA<RecordAudioState>().having(
          (s) => s.status,
          'status',
          RecordAudioStatus.reviewing,
        ),
      ],
    );

    blocTest<RecordAudioCubit, RecordAudioState>(
      'discard returns to idle',
      build: () => RecordAudioCubit(recorder: recorder),
      act: (cubit) async {
        await cubit.start('/tmp/out.m4a');
        await cubit.stop();
        cubit.discard();
      },
      skip: 2,
      expect: () => [const RecordAudioState.idle()],
    );

    blocTest<RecordAudioCubit, RecordAudioState>(
      'save returns to idle',
      build: () => RecordAudioCubit(recorder: recorder),
      act: (cubit) async {
        await cubit.start('/tmp/out.m4a');
        await cubit.stop();
        cubit.save();
      },
      skip: 2,
      expect: () => [const RecordAudioState.idle()],
    );

    blocTest<RecordAudioCubit, RecordAudioState>(
      'cancel mid-recording stops the recorder, drops the file, and '
      'returns to idle',
      build: () => RecordAudioCubit(recorder: recorder),
      act: (cubit) async {
        await cubit.start('/tmp/out.m4a');
        await cubit.cancel();
      },
      skip: 1,
      expect: () => [const RecordAudioState.idle()],
      verify: (_) {
        // The recorder was actually stopped (the mic never stays hot), but
        // no reviewing state was ever surfaced for the abandoned file.
        expect(recorder.stopCalls, 1);
      },
    );

    blocTest<RecordAudioCubit, RecordAudioState>(
      'cancel while not recording just returns to idle without touching '
      'the recorder',
      build: () => RecordAudioCubit(recorder: recorder),
      act: (cubit) => cubit.cancel(),
      expect: () => [const RecordAudioState.idle()],
      verify: (_) {
        expect(recorder.stopCalls, 0);
      },
    );

    test('the 60s cap surfaces reviewing state automatically', () {
      fakeAsync((async) {
        // Built inside the fakeAsync zone (rather than reusing the shared
        // `recorder` from setUp/outer scope): a broadcast StreamController
        // created *outside* a fakeAsync zone schedules its subscription's
        // cancel-completion on the real zone, which `async.flushMicrotasks`
        // can't drain, hanging `stop()` mid-cancel forever.
        final fakeRecorder = _FakeAudioRecorderService();
        final cubit = RecordAudioCubit(recorder: fakeRecorder);
        unawaited(cubit.start('/tmp/out.m4a'));
        async.flushMicrotasks();
        expect(cubit.state.status, RecordAudioStatus.recording);

        async
          ..elapse(RecordAudioCubit.maxDuration + const Duration(seconds: 1))
          ..flushMicrotasks();

        expect(cubit.state.status, RecordAudioStatus.reviewing);
        expect(cubit.state.path, fakeRecorder.stopPath);
        expect(fakeRecorder.stopCalls, 1);

        unawaited(cubit.close());
      });
    });
  });
}
