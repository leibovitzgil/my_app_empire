import 'dart:async';

import 'package:crash_reporting/crash_reporting.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// A unified logger that sends events to Firebase Analytics, errors and
/// breadcrumbs to the injected [CrashReporter], and local logs to Talker.
///
/// Crash reporting rides the `crash_reporting` seam rather than a direct
/// Crashlytics dependency: bind [CrashlyticsCrashReporter] in a real
/// Firebase composition, and the default [NoopCrashReporter] keeps
/// mock/emulator/headless compositions Firebase-free.
class AppLogger {
  /// Creates an [AppLogger].
  ///
  /// [crashReporter] defaults to a no-op; real compositions must inject
  /// their bound [CrashReporter] so errors reach the crash backend.
  AppLogger({
    FirebaseAnalytics? analytics,
    CrashReporter crashReporter = const NoopCrashReporter(),
    Talker? talker,
  }) : _analytics = analytics ?? FirebaseAnalytics.instance,
       _crashReporter = crashReporter,
       _talker = talker ?? TalkerFlutter.init();
  final FirebaseAnalytics _analytics;
  final CrashReporter _crashReporter;
  final Talker _talker;

  /// Returns the underlying Talker instance for UI display.
  Talker get talker => _talker;

  /// Logs a custom event.
  ///
  /// [name] is the name of the event (e.g., 'button_clicked').
  /// [parameters] are optional parameters for the event.
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    _talker.info('Event: $name, Params: $parameters');
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } on Object catch (e, st) {
      _talker.handle(e, st, 'Failed to log event to Firebase');
    }
  }

  /// Logs an informational message.
  void logInfo(String message) {
    _talker.info(message);
    // Add to the crash reporter's breadcrumb log so it appears in reports.
    unawaited(_crashReporter.log(message));
  }

  /// Logs a warning message.
  void logWarning(String message) {
    _talker.warning(message);
    unawaited(_crashReporter.log('WARNING: $message'));
  }

  /// Logs an error with optional exception and stack trace.
  Future<void> logError(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) async {
    _talker.error(message, error, stackTrace);
    try {
      await _crashReporter.recordError(
        (error as Object?) ?? message,
        stackTrace,
        context: message,
      );
    } on Object catch (e, st) {
      debugPrint('Failed to record error to the crash reporter: $e\n$st');
    }
  }
}
