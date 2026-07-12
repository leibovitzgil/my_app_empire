import 'dart:async';

import 'package:audio/audio.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/features/score/score.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAudioPlayerService implements AudioPlayerService {
  bool playThrows = false;
  int playCalls = 0;
  int stopCalls = 0;
  String? lastPlayedPath;

  final _progressController = StreamController<PlaybackProgress>.broadcast();

  @override
  Future<Result<void>> play(String path) async {
    playCalls++;
    lastPlayedPath = path;
    if (playThrows) {
      return const ResultFailure<void>(AudioPlaybackException('boom'));
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> stop() async {
    stopCalls++;
    return const Success<void>(null);
  }

  @override
  Stream<PlaybackProgress> get progress => _progressController.stream;

  void emitProgress(PlaybackProgress progress) =>
      _progressController.add(progress);

  Future<void> dispose() => _progressController.close();
}

void main() {
  group('AudioPlaybackCubit', () {
    late _FakeAudioPlayerService player;

    setUp(() {
      player = _FakeAudioPlayerService();
    });

    test('initial state is idle', () {
      final cubit = AudioPlaybackCubit(player: player);
      expect(cubit.state, const AudioPlaybackState.idle());
      addTearDown(cubit.close);
    });

    blocTest<AudioPlaybackCubit, AudioPlaybackState>(
      'play moves to playing for the given note id',
      build: () => AudioPlaybackCubit(player: player),
      act: (cubit) => cubit.play('note1', '/tmp/a.m4a'),
      expect: () => [const AudioPlaybackState.playing(noteId: 'note1')],
      verify: (_) {
        expect(player.lastPlayedPath, '/tmp/a.m4a');
      },
    );

    blocTest<AudioPlaybackCubit, AudioPlaybackState>(
      'play surfaces an error when the service fails',
      build: () {
        player.playThrows = true;
        return AudioPlaybackCubit(player: player);
      },
      act: (cubit) => cubit.play('note1', '/tmp/a.m4a'),
      expect: () => [
        isA<AudioPlaybackState>().having(
          (s) => s.status,
          'status',
          AudioPlaybackStatus.error,
        ),
      ],
    );

    blocTest<AudioPlaybackCubit, AudioPlaybackState>(
      'progress updates are mirrored into state while playing',
      build: () => AudioPlaybackCubit(player: player),
      act: (cubit) async {
        await cubit.play('note1', '/tmp/a.m4a');
        player.emitProgress(
          const PlaybackProgress(
            position: Duration(seconds: 1),
            duration: Duration(seconds: 4),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        const AudioPlaybackState.playing(noteId: 'note1'),
        const AudioPlaybackState.playing(
          noteId: 'note1',
          progress: PlaybackProgress(
            position: Duration(seconds: 1),
            duration: Duration(seconds: 4),
          ),
        ),
      ],
    );

    blocTest<AudioPlaybackCubit, AudioPlaybackState>(
      'stop returns to idle',
      build: () => AudioPlaybackCubit(player: player),
      act: (cubit) async {
        await cubit.play('note1', '/tmp/a.m4a');
        await cubit.stop();
      },
      expect: () => [
        const AudioPlaybackState.playing(noteId: 'note1'),
        const AudioPlaybackState.idle(),
      ],
      verify: (_) {
        expect(player.stopCalls, 1);
      },
    );

    blocTest<AudioPlaybackCubit, AudioPlaybackState>(
      'playback auto-stops once position reaches duration',
      build: () => AudioPlaybackCubit(player: player),
      act: (cubit) async {
        await cubit.play('note1', '/tmp/a.m4a');
        player.emitProgress(
          const PlaybackProgress(
            position: Duration(seconds: 4),
            duration: Duration(seconds: 4),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        const AudioPlaybackState.playing(noteId: 'note1'),
        const AudioPlaybackState.playing(
          noteId: 'note1',
          progress: PlaybackProgress(
            position: Duration(seconds: 4),
            duration: Duration(seconds: 4),
          ),
        ),
        const AudioPlaybackState.idle(),
      ],
      verify: (_) {
        expect(player.stopCalls, 1);
      },
    );
  });
}
