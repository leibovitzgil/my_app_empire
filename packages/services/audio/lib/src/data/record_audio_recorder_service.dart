import 'dart:async';

import 'package:audio/src/data/audio_record_exception.dart';
import 'package:audio/src/data/recorder_port.dart';
import 'package:audio/src/domain/audio_recorder_service.dart';
import 'package:clock/clock.dart' show clock;
import 'package:core_utils/core_utils.dart';
import 'package:record/record.dart' as record;

/// An [AudioRecorderService] backed by `package:record`, capping recordings
/// at `maxMillis` (60s by default) via a local [Timer] since the plugin
/// itself has no built-in duration cap.
class RecordAudioRecorderService implements AudioRecorderService {
  /// Creates a [RecordAudioRecorderService]. [recorder] defaults to a real
  /// [PackageRecorderPort]; tests inject a fake [RecorderPort]. [now]
  /// defaults to the ambient `package:clock` clock (fakeable in tests via
  /// `fakeAsync`/`withClock`).
  RecordAudioRecorderService({RecorderPort? recorder, DateTime Function()? now})
    : _recorder = recorder ?? PackageRecorderPort(),
      _now = now ?? (() => clock.now());

  final RecorderPort _recorder;
  final DateTime Function() _now;
  final StreamController<Duration> _elapsedController =
      StreamController<Duration>.broadcast();

  Timer? _ticker;
  Timer? _capTimer;
  bool _recording = false;

  @override
  Future<Result<void>> start(String outputPath, {int maxMillis = 60000}) =>
      Result.guard<void>(() async {
        if (_recording) {
          throw const AudioRecordException(
            'A recording is already in progress',
          );
        }
        bool hasPermission;
        try {
          hasPermission = await _recorder.hasPermission();
        } on Object catch (error) {
          throw AudioRecordException(
            'Failed to check microphone permission: $error',
          );
        }
        if (!hasPermission) {
          throw const AudioRecordException('Microphone permission denied');
        }
        try {
          await _recorder.start(const record.RecordConfig(), path: outputPath);
        } on Object catch (error) {
          throw AudioRecordException('Failed to start recording: $error');
        }
        _recording = true;
        final startedAt = _now();
        _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
          if (!_elapsedController.isClosed) {
            _elapsedController.add(_now().difference(startedAt));
          }
        });
        _capTimer = Timer(Duration(milliseconds: maxMillis), () {
          unawaited(stop());
        });
      });

  @override
  Future<Result<String>> stop() => Result.guard<String>(() async {
    if (!_recording) {
      throw const AudioRecordException('No active recording to stop');
    }
    _recording = false;
    _ticker?.cancel();
    _ticker = null;
    _capTimer?.cancel();
    _capTimer = null;
    String? path;
    try {
      path = await _recorder.stop();
    } on Object catch (error) {
      throw AudioRecordException('Failed to stop recording: $error');
    }
    if (path == null) {
      throw const AudioRecordException(
        'The recorder stopped without producing an output file',
      );
    }
    return path;
  });

  @override
  Stream<Duration> get elapsed => _elapsedController.stream;

  /// Whether a recording is currently in progress.
  bool get isRecording => _recording;

  /// Releases native recorder resources and closes [elapsed]. Call this from
  /// the owning bloc/widget's `dispose()`.
  Future<void> dispose() async {
    _ticker?.cancel();
    _capTimer?.cancel();
    await _recorder.dispose();
    await _elapsedController.close();
  }
}
