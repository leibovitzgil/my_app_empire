import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// A narrow seam over `package:flutter_local_notifications` so
/// `NotificationsManager`'s local-notification logic (argument mapping,
/// exception handling) can be unit tested without a platform channel (the
/// real plugin needs a device or emulator) — mirrors `services/audio`'s
/// `RecorderPort`/`PlayerPort` convention. A single-method port here (rather
/// than a bare typedef) so a fake implementation can also track call state
/// (as `_FakeRecorderPort` does), the same reasoning that convention applies.
// ignore: one_member_abstracts
abstract class LocalNotificationPort {
  /// Shows a local notification with the given [id]/[title]/[body].
  /// [id] identifies the notification for later replacement/dismissal; a
  /// distinct value per call means each posted notification stays visible
  /// on its own rather than replacing the previous one.
  Future<void> show({
    required int id,
    required String title,
    required String body,
  });
}

/// The default [LocalNotificationPort], backed by a real
/// [FlutterLocalNotificationsPlugin]. Initializes the plugin lazily, once,
/// on the first [show] call.
class PluginLocalNotificationPort implements LocalNotificationPort {
  /// Creates a [PluginLocalNotificationPort] wrapping a fresh
  /// [FlutterLocalNotificationsPlugin].
  PluginLocalNotificationPort() : _plugin = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'default_channel';
  static const String _channelName = 'General notifications';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(_channelId, _channelName),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }
}
