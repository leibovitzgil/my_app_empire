import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// A narrow seam over `package:flutter_local_notifications` so
/// `NotificationsManager`'s local-notification logic (argument mapping,
/// exception handling) can be unit tested without a platform channel (the
/// real plugin needs a device or emulator) — mirrors `services/audio`'s
/// `RecorderPort`/`PlayerPort` convention, with a fake implementation able
/// to also track call state (as `_FakeRecorderPort` does).
abstract class LocalNotificationPort {
  /// Shows a local notification with the given [id]/[title]/[body].
  /// [id] identifies the notification for later replacement/dismissal; a
  /// distinct value per call means each posted notification stays visible
  /// on its own rather than replacing the previous one.
  ///
  /// [payload] is an opaque string attached to the notification and echoed
  /// back on [onTap] when the user taps it — apps typically put a deep-link
  /// URI here so a tap can route to the exact content the notification is
  /// about (M5.5).
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// Payloads of notifications the user tapped while the app was running.
  /// Taps on notifications posted without a payload are not emitted — there
  /// is nothing to route on.
  Stream<String> get onTap;
}

/// The default [LocalNotificationPort], backed by a real
/// [FlutterLocalNotificationsPlugin]. Initializes the plugin lazily, once,
/// on the first [show] call — which also registers the tap callback feeding
/// [onTap], so taps are only observable after something was shown through
/// this port (cold-start taps on an FCM push are Track B's
/// `getInitialMessage` concern, not this seam's).
class PluginLocalNotificationPort implements LocalNotificationPort {
  /// Creates a [PluginLocalNotificationPort] wrapping a fresh
  /// [FlutterLocalNotificationsPlugin].
  PluginLocalNotificationPort() : _plugin = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'default_channel';
  static const String _channelName = 'General notifications';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _taps = StreamController<String>.broadcast();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onResponse,
    );
    _initialized = true;
  }

  void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _taps.add(payload);
  }

  @override
  Stream<String> get onTap => _taps.stream;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _ensureInitialized();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(_channelId, _channelName),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }
}
