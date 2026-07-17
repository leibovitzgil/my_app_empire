import 'dart:async';

import 'package:crash_reporting/crash_reporting.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// A unified logger that sends events to Firebase Analytics, errors and
/// breadcrumbs to the injected [CrashReporter], and local logs to Talker.
///
/// Both backends are opt-in seams, so the default `AppLogger()` is entirely
/// Firebase-free (safe for mock/emulator/headless compositions):
///
/// - Analytics: pass [FirebaseAnalytics.instance] in a real Firebase
///   composition (after `Firebase.initializeApp`). With no analytics
///   instance, events are logged locally to Talker only.
/// - Crash reporting rides the `crash_reporting` seam rather than a direct
///   Crashlytics dependency: bind [CrashlyticsCrashReporter] in a real
///   Firebase composition, and the default [NoopCrashReporter] keeps the
///   rest Firebase-free.
class AppLogger {
  /// Creates an [AppLogger].
  ///
  /// [analytics] defaults to none (events log to Talker only); real
  /// compositions pass [FirebaseAnalytics.instance]. [crashReporter]
  /// defaults to a no-op; real compositions must inject their bound
  /// [CrashReporter] so errors reach the crash backend.
  AppLogger({
    FirebaseAnalytics? analytics,
    CrashReporter crashReporter = const NoopCrashReporter(),
    Talker? talker,
  }) : _analytics = analytics,
       _crashReporter = crashReporter,
       _talker = talker ?? TalkerFlutter.init();
  final FirebaseAnalytics? _analytics;
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
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logEvent(name: name, parameters: parameters);
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
