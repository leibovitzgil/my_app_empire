import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// A unified logger that sends events to Firebase Analytics,
/// errors to Crashlytics, and local logs to Talker.
class AppLogger {
  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;
  final Talker _talker;

  AppLogger({
    FirebaseAnalytics? analytics,
    FirebaseCrashlytics? crashlytics,
    Talker? talker,
  })  : _analytics = analytics ?? FirebaseAnalytics.instance,
        _crashlytics = crashlytics ?? FirebaseCrashlytics.instance,
        _talker = talker ?? TalkerFlutter.init();

  /// Returns the underlying Talker instance for UI display.
  Talker get talker => _talker;

  /// Logs a custom event.
  ///
  /// [name] is the name of the event (e.g., 'button_clicked').
  /// [parameters] are optional parameters for the event.
  Future<void> logEvent(String name, [Map<String, Object?>? parameters]) async {
    _talker.info('Event: $name, Params: $parameters');
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e, st) {
      _talker.handle(e, st, 'Failed to log event to Firebase');
    }
  }

  /// Logs an informational message.
  void logInfo(String message) {
    _talker.info(message);
    // Add to Crashlytics logs so it appears in crash reports
    _crashlytics.log(message);
  }

  /// Logs a warning message.
  void logWarning(String message) {
    _talker.warning(message);
    _crashlytics.log('WARNING: $message');
  }

  /// Logs an error with optional exception and stack trace.
  Future<void> logError(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) async {
    _talker.error(message, error, stackTrace);
    try {
      await _crashlytics.recordError(error, stackTrace, reason: message);
    } catch (e, st) {
      debugPrint('Failed to record error to Crashlytics: $e\n$st');
    }
  }
}
