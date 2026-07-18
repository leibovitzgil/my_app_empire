import 'package:crash_reporting/crash_reporting.dart';

/// A recorded [FakeCrashReporter.recordError] call.
class RecordedError {
  RecordedError({
    required this.error,
    required this.stack,
    required this.fatal,
    required this.context,
  });

  final Object error;
  final StackTrace? stack;
  final bool fatal;
  final String? context;
}

/// A [CrashReporter] that captures every call for assertions.
class FakeCrashReporter implements CrashReporter {
  final List<RecordedError> recordedErrors = <RecordedError>[];
  final List<String> loggedMessages = <String>[];
  final List<String?> userIds = <String?>[];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  }) async {
    recordedErrors.add(
      RecordedError(
        error: error,
        stack: stack,
        fatal: fatal,
        context: context,
      ),
    );
  }

  @override
  Future<void> log(String message) async {
    loggedMessages.add(message);
  }

  @override
  Future<void> setUserId(String? uid) async {
    userIds.add(uid);
  }
}
