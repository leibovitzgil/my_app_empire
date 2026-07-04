import 'package:audio/src/domain/audio_recorder_service.dart';
import 'package:core_utils/core_utils.dart';

/// An [AudioRecorderService] backed by `package:record`. Real recording
/// lands in a later phase; this keeps the package compiling end-to-end
/// against the contract in the meantime.
class RecordAudioRecorderService implements AudioRecorderService {
  @override
  Future<Result<void>> start(String outputPath, {int maxMillis = 60000}) =>
      throw UnimplementedError();

  @override
  Future<Result<String>> stop() => throw UnimplementedError();

  @override
  Stream<Duration> get elapsed => throw UnimplementedError();
}
