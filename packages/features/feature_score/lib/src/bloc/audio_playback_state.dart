part of 'audio_playback_cubit.dart';

/// The phase of [AudioPlaybackCubit]'s playback.
enum AudioPlaybackStatus { idle, playing, error }

/// Immutable state for [AudioPlaybackCubit].
final class AudioPlaybackState extends Equatable {
  const AudioPlaybackState._({
    this.status = AudioPlaybackStatus.idle,
    this.noteId,
    this.progress,
    this.error,
  });

  /// Nothing is playing.
  const AudioPlaybackState.idle() : this._();

  /// The audio note [noteId] is playing, with an optional [progress]
  /// snapshot (null for the instant between starting playback and the
  /// first progress tick).
  const AudioPlaybackState.playing({
    required String noteId,
    PlaybackProgress? progress,
  }) : this._(
         status: AudioPlaybackStatus.playing,
         noteId: noteId,
         progress: progress,
       );

  /// Playback failed.
  const AudioPlaybackState.error(String error)
    : this._(status: AudioPlaybackStatus.error, error: error);

  /// The current phase.
  final AudioPlaybackStatus status;

  /// The id of the audio note currently playing, once [status] is
  /// [AudioPlaybackStatus.playing].
  final String? noteId;

  /// The most recent playback position/duration snapshot.
  final PlaybackProgress? progress;

  /// A human-readable failure message, once [status] is
  /// [AudioPlaybackStatus.error].
  final String? error;

  /// Whether [noteId] is the pin currently playing.
  bool isPlaying(String noteId) =>
      status == AudioPlaybackStatus.playing && this.noteId == noteId;

  @override
  List<Object?> get props => [status, noteId, progress, error];
}
