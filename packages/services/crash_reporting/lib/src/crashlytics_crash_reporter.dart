import 'package:crash_reporting/src/crash_reporter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// A [CrashReporter] backed by Firebase Crashlytics.
///
/// Only construct this from a composition that has already called
/// `Firebase.initializeApp()` — the default instance throws otherwise.
/// Mock/emulator/headless compositions bind `NoopCrashReporter` instead.
class CrashlyticsCrashReporter implements CrashReporter {
  /// Creates a Crashlytics-backed reporter over [crashlytics] (the default
  /// instance when omitted).
  CrashlyticsCrashReporter({FirebaseCrashlytics? crashlytics})
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  }) => _crashlytics.recordError(
    error,
    stack,
    fatal: fatal,
    reason: context,
  );

  @override
  Future<void> log(String message) => _crashlytics.log(message);

  @override
  Future<void> setUserId(String? uid) =>
      // Crashlytics has no "clear" API; the documented idiom for sign-out
      // is setting the empty string.
      _crashlytics.setUserIdentifier(uid ?? '');
}
