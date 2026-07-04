import 'dart:async';

import 'package:audio/src/data/audio_playback_exception.dart';
import 'package:audio/src/data/player_port.dart';
import 'package:audio/src/domain/audio_player_service.dart';
import 'package:audio/src/domain/playback_progress.dart';
import 'package:core_utils/core_utils.dart';

/// An [AudioPlayerService] backed by `package:just_audio`, composing its
/// separate position/duration streams into a single [PlaybackProgress]
/// stream.
class JustAudioPlayerService implements AudioPlayerService {
  /// Creates a [JustAudioPlayerService]. [player] defaults to a real
  /// [PackagePlayerPort]; tests inject a fake [PlayerPort].
  JustAudioPlayerService({PlayerPort? player})
    : _player = player ?? PackagePlayerPort();

  final PlayerPort _player;

  @override
  Future<Result<void>> play(String path) => Result.guard<void>(() async {
    try {
      await _player.setFilePath(path);
    } on Object catch (error) {
      throw AudioPlaybackException('Failed to load audio at $path: $error');
    }
    try {
      await _player.play();
    } on Object catch (error) {
      throw AudioPlaybackException('Failed to start playback: $error');
    }
  });

  @override
  Future<Result<void>> stop() => Result.guard<void>(() async {
    try {
      await _player.stop();
    } on Object catch (error) {
      throw AudioPlaybackException('Failed to stop playback: $error');
    }
  });

  @override
  Stream<PlaybackProgress> get progress {
    late final StreamController<PlaybackProgress> controller;
    StreamSubscription<Duration?>? durationSub;
    StreamSubscription<Duration>? positionSub;
    var duration = Duration.zero;
    controller = StreamController<PlaybackProgress>.broadcast(
      onListen: () {
        durationSub = _player.durationStream.listen((d) {
          duration = d ?? Duration.zero;
        });
        positionSub = _player.positionStream.listen((position) {
          if (!controller.isClosed) {
            controller.add(
              PlaybackProgress(position: position, duration: duration),
            );
          }
        });
      },
      onCancel: () async {
        await durationSub?.cancel();
        await positionSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Releases native player resources. Call this from the owning
  /// bloc/widget's `dispose()`.
  Future<void> dispose() => _player.dispose();
}
