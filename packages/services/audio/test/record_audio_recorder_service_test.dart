import 'dart:async';

import 'package:audio/audio.dart';
import 'package:core_utils/core_utils.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart' as record;

class _FakeRecorderPort implements RecorderPort {
  bool permission = true;
  bool startThrows = false;
  String? stopPath = '/tmp/note.m4a';
  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  record.RecordConfig? lastConfig;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> start(record.RecordConfig config, {required String path}) async {
    startCalls++;
    lastConfig = config;
    if (startThrows) throw Exception('boom');
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    return stopPath;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

void main() {
  group('RecordAudioRecorderService', () {
    late _FakeRecorderPort fakeRecorder;
    late RecordAudioRecorderService service;

    setUp(() {
      fakeRecorder = _FakeRecorderPort();
      service = RecordAudioRecorderService(recorder: fakeRecorder);
    });

    test(
      'start records with the explicit AAC-LC 64 kbps mono config (M8.3)',
      () async {
        final result = await service.start('/tmp/out.m4a');

        expect(result, isA<Success<void>>());
        final config = fakeRecorder.lastConfig;
        expect(config, same(RecordAudioRecorderService.recordConfig));
        expect(config?.encoder, record.AudioEncoder.aacLc);
        expect(config?.bitRate, 64000);
        expect(config?.sampleRate, 44100);
        expect(config?.numChannels, 1);
        await service.stop();
      },
    );

    test('start fails when microphone permission is denied', () async {
      fakeRecorder.permission = false;

      final result = await service.start('/tmp/out.m4a');

      expect(result, isA<ResultFailure<void>>());
      expect(
        (result as ResultFailure<void>).error,
        isA<AudioRecordException>(),
      );
      expect(fakeRecorder.startCalls, 0);
    });

    test('start fails while a recording is already in progress', () async {
      final first = await service.start('/tmp/out.m4a');
      expect(first, isA<Success<void>>());

      final second = await service.start('/tmp/out2.m4a');

      expect(second, isA<ResultFailure<void>>());
      expect(fakeRecorder.startCalls, 1);
      await service.stop();
    });

    test('stop fails when no recording is in progress', () async {
      final result = await service.stop();

      expect(result, isA<ResultFailure<String>>());
      expect(fakeRecorder.stopCalls, 0);
    });

    test("stop returns the recorder's output path", () async {
      await service.start('/tmp/out.m4a');

      final result = await service.stop();

      expect(result, isA<Success<String>>());
      expect((result as Success<String>).value, '/tmp/note.m4a');
      expect(service.isRecording, isFalse);
    });

    test('elapsed emits increasing durations while recording', () {
      fakeAsync((async) {
        Result<void>? startResult;
        unawaited(service.start('/tmp/out.m4a').then((r) => startResult = r));
        async.flushMicrotasks();
        expect(startResult, isA<Success<void>>());

        final emissions = <Duration>[];
        final subscription = service.elapsed.listen(emissions.add);

        async.elapse(const Duration(milliseconds: 350));

        expect(emissions.length, greaterThanOrEqualTo(3));
        expect(emissions.last, greaterThan(emissions.first));

        unawaited(subscription.cancel());
      });
    });

    test('auto-stops after maxMillis without an explicit stop() call', () {
      fakeAsync((async) {
        Result<void>? startResult;
        unawaited(
          service
              .start('/tmp/out.m4a', maxMillis: 200)
              .then((r) => startResult = r),
        );
        async.flushMicrotasks();
        expect(startResult, isA<Success<void>>());
        expect(service.isRecording, isTrue);

        async.elapse(const Duration(milliseconds: 250));

        expect(service.isRecording, isFalse);
        expect(fakeRecorder.stopCalls, 1);
      });
    });

    test('dispose cancels timers and releases the recorder', () async {
      await service.start('/tmp/out.m4a');
      await service.dispose();

      expect(fakeRecorder.disposeCalls, 1);
    });
  });
}
