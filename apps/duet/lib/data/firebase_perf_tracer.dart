import 'dart:async';

import 'package:duet/data/perf_tracer.dart';
import 'package:firebase_performance/firebase_performance.dart';

/// The real [PerfTracer], backed by `firebase_performance` (M7.3).
///
/// Wired ONLY under the real Firebase entry point (Track B, M0.2): it reads a
/// [FirebasePerformance] instance, which requires a real
/// `Firebase.initializeApp` and has no emulator backend — so the mock and
/// emulator compositions bind [NoopPerfTracer] instead, exactly like the
/// M6.4 remote-config and M7.1/M7.2 analytics/crash bindings (G2). See the
/// `TODO(track-b)` in `injection.dart`.
class FirebasePerfTracer implements PerfTracer {
  /// Creates a [FirebasePerfTracer] over a [FirebasePerformance] instance
  /// (typically `FirebasePerformance.instance`).
  FirebasePerfTracer(this._performance);

  final FirebasePerformance _performance;

  @override
  PerfTrace? start(String name) {
    final trace = _performance.newTrace(name);
    // Fire-and-forget: callers never await the trace lifecycle on a hot path
    // (M7.3 step 4). Sampling/collection-enabled decisions are Firebase's.
    unawaited(trace.start());
    return _FirebasePerfTrace(trace);
  }
}

class _FirebasePerfTrace implements PerfTrace {
  _FirebasePerfTrace(this._trace);

  final Trace _trace;

  @override
  void putAttribute(String name, String value) =>
      _trace.putAttribute(name, value);

  @override
  void stop() => unawaited(_trace.stop());
}
