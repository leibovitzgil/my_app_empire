import 'package:audio/src/domain/audio_player_service.dart';
import 'package:audio/src/domain/playback_progress.dart';
import 'package:core_utils/core_utils.dart';

/// An [AudioPlayerService] backed by `package:just_audio`. Real playback
/// lands in a later phase; this keeps the package compiling end-to-end
/// against the contract in the meantime.
class JustAudioPlayerService implements AudioPlayerService {
  @override
  Future<Result<void>> play(String path) => throw UnimplementedError();

  @override
  Future<Result<void>> stop() => throw UnimplementedError();

  @override
  Stream<PlaybackProgress> get progress => throw UnimplementedError();
}
