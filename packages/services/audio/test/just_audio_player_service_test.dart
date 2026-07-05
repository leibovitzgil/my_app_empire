import 'dart:async';

import 'package:audio/audio.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlayerPort implements PlayerPort {
  bool setFilePathThrows = false;
  int setFilePathCalls = 0;
  int playCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();

  void emitPosition(Duration position) => _positionController.add(position);

  void emitDuration(Duration? duration) => _durationController.add(duration);

  @override
  Future<void> setFilePath(String path) async {
    setFilePathCalls++;
    if (setFilePathThrows) throw Exception('boom');
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _positionController.close();
    await _durationController.close();
  }
}

void main() {
  group('JustAudioPlayerService', () {
    late _FakePlayerPort fakePlayer;
    late JustAudioPlayerService service;

    setUp(() {
      fakePlayer = _FakePlayerPort();
      service = JustAudioPlayerService(player: fakePlayer);
    });

    tearDown(() => service.dispose());

    test('play loads the file then starts playback', () async {
      final result = await service.play('/tmp/note.m4a');

      expect(result, isA<Success<void>>());
      expect(fakePlayer.setFilePathCalls, 1);
      expect(fakePlayer.playCalls, 1);
    });

    test('play surfaces a load failure as AudioPlaybackException', () async {
      fakePlayer.setFilePathThrows = true;

      final result = await service.play('/tmp/missing.m4a');

      expect(result, isA<ResultFailure<void>>());
      expect(
        (result as ResultFailure<void>).error,
        isA<AudioPlaybackException>(),
      );
      expect(fakePlayer.playCalls, 0);
    });

    test('stop delegates to the player', () async {
      final result = await service.stop();

      expect(result, isA<Success<void>>());
      expect(fakePlayer.stopCalls, 1);
    });

    test('progress combines position and duration updates', () async {
      final emissions = <PlaybackProgress>[];
      final subscription = service.progress.listen(emissions.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      fakePlayer
        ..emitDuration(const Duration(seconds: 10))
        ..emitPosition(const Duration(seconds: 2));
      await pumpEventQueue();

      expect(emissions, isNotEmpty);
      expect(
        emissions.last,
        const PlaybackProgress(
          position: Duration(seconds: 2),
          duration: Duration(seconds: 10),
        ),
      );
    });

    test(
      'progress reflects duration updates that arrive after position',
      () async {
        final emissions = <PlaybackProgress>[];
        final subscription = service.progress.listen(emissions.add);
        addTearDown(subscription.cancel);
        await pumpEventQueue();

        fakePlayer.emitPosition(const Duration(seconds: 1));
        await pumpEventQueue();
        expect(emissions.last.duration, Duration.zero);

        fakePlayer
          ..emitDuration(const Duration(seconds: 30))
          ..emitPosition(const Duration(seconds: 2));
        await pumpEventQueue();
        expect(emissions.last.duration, const Duration(seconds: 30));
      },
    );
  });
}
