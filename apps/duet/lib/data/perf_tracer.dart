/// A running performance trace (M7.3): carries string attributes and stops.
///
/// Deliberately a Firebase-free seam. The two hot-path consumers —
/// `TracedPdfRenderService` and `DuetScorePage`'s reader-open trace — and
/// their tests talk to this, never to `firebase_performance`, so Firebase
/// stays off the headless gate (G2) and the decorator stays unit-testable
/// with a fake recorder.
abstract class PerfTrace {
  /// Attaches a string [value] under [name] to this trace. Must be a cheap,
  /// synchronous call — nothing on a caller's critical path awaits it.
  void putAttribute(String name, String value);

  /// Stops the trace. Fire-and-forget by contract: implementations must never
  /// make callers await backend I/O (M7.3 step 4 — no synchronous work is
  /// added to the render critical path).
  void stop();
}

/// Starts named performance traces — the injection seam for M7.3.
///
/// Two implementations exist: [NoopPerfTracer] (bound on the headless/mock
/// and emulator compositions — every [start] returns null, so consumers are
/// pure pass-throughs and no Firebase object is ever built, G2) and
/// `FirebasePerfTracer` (`firebase_perf_tracer.dart`, the real
/// `firebase_performance`-backed tracer, wired only under the real Firebase
/// entry point in Track B).
///
/// A DI seam with two real implementations (noop + Firebase-backed), not a
/// function type — hence the `one_member_abstracts` ignore.
// ignore: one_member_abstracts
abstract class PerfTracer {
  /// Starts and returns a running trace named [name], or null when tracing is
  /// disabled (no real Performance backend). A null trace means the caller
  /// adds zero work to its critical path.
  PerfTrace? start(String name);
}

/// A [PerfTracer] that never traces: [start] always returns null. Bound on
/// the mock and emulator compositions, where no real Firebase Performance
/// backend exists (G2).
class NoopPerfTracer implements PerfTracer {
  @override
  PerfTrace? start(String name) => null;
}
