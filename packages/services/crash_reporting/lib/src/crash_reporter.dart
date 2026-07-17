/// The factory's crash-reporting seam.
///
/// Blocs, services, and app glue depend on this contract; apps bind an
/// implementation at the DI layer — `CrashlyticsCrashReporter` in a real
/// Firebase composition, `NoopCrashReporter` everywhere else (mock,
/// emulator, and the headless test gate, which must never construct a
/// Firebase object).
///
/// Identity note: [setUserId] takes a *uid* only. Never pass an email or
/// any other PII — the uid is enough to correlate a crash with a session.
abstract class CrashReporter {
  /// Records [error] with its [stack].
  ///
  /// [fatal] marks the error as a crash (vs. a caught, non-fatal error).
  /// [context] is a short human-readable hint about where the error was
  /// caught (e.g. a Flutter error context description).
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  });

  /// Adds [message] to the breadcrumb log attached to subsequent reports.
  Future<void> log(String message);

  /// Associates subsequent reports with [uid]; pass null on sign-out to
  /// clear the association. Uid only — never an email.
  Future<void> setUserId(String? uid);
}
