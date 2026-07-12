import 'dart:async';

import 'package:audio/audio.dart';
import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';

part 'record_audio_state.dart';

/// Drives the "record an audio note" flow: wraps [AudioRecorderService] and
/// exposes idle/recording/reviewing/error states.
///
/// [AudioRecorderService] itself caps a recording at `maxMillis` via its own
/// internal timer, but has no way to notify an external caller when *that*
/// timer (rather than an explicit [stop] call) ends a recording — the only
/// signal a caller gets back is the return value of its own [stop] call.
/// So this cubit runs its own [maxDuration] timer and is the one that always
/// calls [AudioRecorderService.stop] when the cap is hit, guaranteeing it
/// captures the resulting file and transitions to `reviewing`. The service
/// is still given a longer `maxMillis` as a backstop, in case this cubit's
/// timer doesn't fire (e.g. the app was suspended).
class RecordAudioCubit extends Cubit<RecordAudioState> {
  /// Creates a [RecordAudioCubit] wrapping [recorder].
  RecordAudioCubit({required AudioRecorderService recorder})
    : _recorder = recorder,
      super(const RecordAudioState.idle());

  /// The recording length after which [start] automatically stops and
  /// surfaces the `reviewing` state.
  static const Duration maxDuration = Duration(seconds: 60);

  static const Duration _serviceCapBackstop = Duration(seconds: 65);

  final AudioRecorderService _recorder;
  StreamSubscription<Duration>? _elapsedSubscription;
  Timer? _capTimer;

  /// Starts recording to [outputPath]. Surfaces `error` (e.g. on a denied
  /// microphone permission) instead of throwing.
  Future<void> start(String outputPath) async {
    final result = await _recorder.start(
      outputPath,
      maxMillis: _serviceCapBackstop.inMilliseconds,
    );
    switch (result) {
      case Success<void>():
        emit(const RecordAudioState.recording());
        // Not awaited: a stream subscription's cancel-completion isn't
        // needed before continuing (no more events from it matter either
        // way), and depending on it here is a real, load-bearing footgun —
        // see the `RecordAudioCubit` test for why.
        final previousSubscription = _elapsedSubscription;
        if (previousSubscription != null) {
          unawaited(previousSubscription.cancel());
        }
        _elapsedSubscription = _recorder.elapsed.listen(
          (elapsed) => emit(RecordAudioState.recording(elapsed: elapsed)),
        );
        _capTimer?.cancel();
        _capTimer = Timer(maxDuration, () => unawaited(stop()));
      case ResultFailure<void>(:final error):
        emit(RecordAudioState.error('$error'));
    }
  }

  /// Stops the current recording (if any) and moves to `reviewing`. Also
  /// called automatically when [maxDuration] elapses.
  Future<void> stop() async {
    if (state.status != RecordAudioStatus.recording) return;
    final elapsedAtStop = state.elapsed;
    _capTimer?.cancel();
    _capTimer = null;
    final subscription = _elapsedSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    _elapsedSubscription = null;
    final result = await _recorder.stop();
    switch (result) {
      case Success<String>(:final value):
        emit(RecordAudioState.reviewing(path: value, elapsed: elapsedAtStop));
      case ResultFailure<String>(:final error):
        emit(RecordAudioState.error('$error'));
    }
  }

  /// Discards the reviewed recording and returns to `idle`.
  void discard() => emit(const RecordAudioState.idle());

  /// Abandons whatever is in flight and returns to `idle` — stops the
  /// recorder if it's still running (so the mic never stays hot after the
  /// record UI unmounts mid-recording) and throws the result away.
  Future<void> cancel() async {
    if (state.status == RecordAudioStatus.recording) {
      _capTimer?.cancel();
      _capTimer = null;
      final subscription = _elapsedSubscription;
      if (subscription != null) unawaited(subscription.cancel());
      _elapsedSubscription = null;
      // The stopped file is deliberately dropped, success or failure.
      await _recorder.stop();
    }
    if (!isClosed) emit(const RecordAudioState.idle());
  }

  /// Confirms the reviewed recording is being kept (the caller is
  /// responsible for turning its path/duration into a saved audio note via
  /// `ScoreBloc.add(AudioNoteSaved(...))`) and returns to `idle`.
  void save() => emit(const RecordAudioState.idle());

  @override
  Future<void> close() async {
    _capTimer?.cancel();
    await _elapsedSubscription?.cancel();
    return super.close();
  }
}
