import 'package:crash_reporting/src/crash_reporter.dart';

/// A [CrashReporter] that swallows everything.
///
/// Bound by mock/emulator compositions and the headless test gate, where
/// constructing a Firebase object is forbidden (the emulator suite has no
/// Crashlytics emulator, so there is nothing to report to anyway).
class NoopCrashReporter implements CrashReporter {
  /// Creates a no-op reporter.
  const NoopCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  }) async {}

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> setUserId(String? uid) async {}
}
