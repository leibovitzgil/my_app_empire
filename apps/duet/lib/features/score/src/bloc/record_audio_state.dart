part of 'record_audio_cubit.dart';

/// The phase of [RecordAudioCubit]'s recording flow.
enum RecordAudioStatus { idle, recording, reviewing, error }

/// Immutable state for [RecordAudioCubit].
final class RecordAudioState extends Equatable {
  const RecordAudioState._({
    this.status = RecordAudioStatus.idle,
    this.elapsed = Duration.zero,
    this.path,
    this.error,
  });

  /// No recording in progress or under review.
  const RecordAudioState.idle() : this._();

  /// A recording is in progress, [elapsed] seconds in.
  const RecordAudioState.recording({Duration elapsed = Duration.zero})
    : this._(status: RecordAudioStatus.recording, elapsed: elapsed);

  /// A recording finished and is available at [path] for review before
  /// saving or discarding.
  const RecordAudioState.reviewing({
    required String path,
    required Duration elapsed,
  }) : this._(
         status: RecordAudioStatus.reviewing,
         path: path,
         elapsed: elapsed,
       );

  /// Recording failed, e.g. a denied microphone permission.
  const RecordAudioState.error(String error)
    : this._(status: RecordAudioStatus.error, error: error);

  /// The current phase.
  final RecordAudioStatus status;

  /// How long the current/just-finished recording ran.
  final Duration elapsed;

  /// The recorded file's path, once [status] is [RecordAudioStatus.reviewing].
  final String? path;

  /// A human-readable failure message, once [status] is
  /// [RecordAudioStatus.error].
  final String? error;

  @override
  List<Object?> get props => [status, elapsed, path, error];
}
