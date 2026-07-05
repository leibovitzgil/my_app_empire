import 'dart:async';

import 'package:audio/audio.dart';
import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';

part 'audio_playback_state.dart';

/// Drives audio-note playback: wraps [AudioPlayerService] and tracks which
/// pin (if any) is currently playing plus its [PlaybackProgress], so
/// `AudioPinMarker` can render a progress ring.
///
/// A single cubit instance is shared across all pins on a screen (only one
/// can play at a time); [play] stops whatever was previously playing first.
class AudioPlaybackCubit extends Cubit<AudioPlaybackState> {
  /// Creates an [AudioPlaybackCubit] wrapping [player].
  AudioPlaybackCubit({required AudioPlayerService player})
    : _player = player,
      super(const AudioPlaybackState.idle());

  final AudioPlayerService _player;
  StreamSubscription<PlaybackProgress>? _progressSubscription;

  /// Starts playing the audio note [noteId] from [path]. Stops anything
  /// already playing first.
  Future<void> play(String noteId, String path) async {
    await _teardown();
    final result = await _player.play(path);
    switch (result) {
      case Success<void>():
        emit(AudioPlaybackState.playing(noteId: noteId));
        _progressSubscription = _player.progress.listen((progress) {
          emit(AudioPlaybackState.playing(noteId: noteId, progress: progress));
          if (progress.duration > Duration.zero &&
              progress.position >= progress.duration) {
            unawaited(stop());
          }
        });
      case ResultFailure<void>(:final error):
        emit(AudioPlaybackState.error('$error'));
    }
  }

  /// Stops playback, if any, and returns to `idle`.
  Future<void> stop() async {
    await _teardown();
    await _player.stop();
    emit(const AudioPlaybackState.idle());
  }

  Future<void> _teardown() async {
    await _progressSubscription?.cancel();
    _progressSubscription = null;
  }

  @override
  Future<void> close() async {
    await _teardown();
    return super.close();
  }
}
