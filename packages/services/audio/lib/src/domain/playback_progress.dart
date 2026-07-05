import 'package:equatable/equatable.dart';

/// A point-in-time snapshot of an in-progress playback.
class PlaybackProgress extends Equatable {
  /// Creates a [PlaybackProgress].
  const PlaybackProgress({required this.position, required this.duration});

  /// How far into the recording playback currently is.
  final Duration position;

  /// The total duration of the recording being played.
  final Duration duration;

  @override
  List<Object?> get props => [position, duration];
}
