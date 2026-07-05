import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:notifications/src/data/local_notification_exception.dart';
import 'package:notifications/src/data/local_notification_port.dart';
import 'package:notifications/src/ui/soft_prompt_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A read-only snapshot of the OS notification permission, exposed without
/// triggering a system prompt.
enum NotificationPermissionStatus {
  /// Authorized or provisional — notifications may be delivered.
  authorized,

  /// Explicitly denied; the OS will not show another system prompt.
  denied,

  /// Not yet requested — a prompt can still be shown.
  notDetermined,
}

class NotificationsManager {
  /// Creates a [NotificationsManager]. [localNotifications] defaults to a
  /// real [PluginLocalNotificationPort]; tests inject a fake
  /// [LocalNotificationPort] to avoid the platform channel.
  NotificationsManager(
    this._firebaseMessaging,
    this._prefs, {
    LocalNotificationPort? localNotifications,
  }) : _localNotifications =
           localNotifications ?? PluginLocalNotificationPort();

  static const String _kSoftPromptDeclinedKey =
      'notifications_soft_prompt_declined_timestamp';
  // Cooldown in days before showing soft prompt again
  static const int _kSoftPromptCooldownDays = 7;

  final FirebaseMessaging _firebaseMessaging;
  final SharedPreferences _prefs;
  final LocalNotificationPort _localNotifications;

  /// Creates a [NotificationsManager] with default dependencies.
  static Future<NotificationsManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationsManager(FirebaseMessaging.instance, prefs);
  }

  /// Request permission for notifications.
  ///
  /// Returns `true` if permission is granted (or provisional).
  ///
  /// [useSoftPrompt] if true, shows a dialog explaining why notifications are
  /// needed before requesting system permission. This is highly recommended
  /// for iOS and Android 13+.
  ///
  /// [context] is required if [useSoftPrompt] is true.
  Future<bool> requestPermission({
    BuildContext? context,
    bool useSoftPrompt = true,
  }) async {
    // 1. Check current status (side-effect-free).
    final status = await permissionStatus();

    if (status == NotificationPermissionStatus.authorized) return true;

    if (status == NotificationPermissionStatus.denied) {
      // Already denied. Cannot ask again via system prompt.
      return false;
    }

    // Status is notDetermined.

    if (useSoftPrompt && context != null) {
      // Check if we should show soft prompt
      if (!_canShowSoftPrompt()) {
        // Soft prompt in cooldown.
        return false;
      }

      // Guard against using the context if it was unmounted during the
      // preceding async work.
      if (!context.mounted) return false;

      final userAgreed =
          await showDialog<bool>(
            context: context,
            builder: (ctx) => SoftPromptDialog(
              onAllow: () => Navigator.of(ctx).pop(true),
              onLater: () => Navigator.of(ctx).pop(false),
            ),
          ) ??
          false;

      if (!userAgreed) {
        await _markSoftPromptDeclined();
        return false;
      }
    }

    // User agreed or soft prompt disabled/not possible.
    final newSettings = await _firebaseMessaging.requestPermission();

    return newSettings.authorizationStatus == AuthorizationStatus.authorized ||
        newSettings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Reads the current OS notification permission without prompting the user.
  ///
  /// Unlike [requestPermission], this is side-effect-free: it never shows the
  /// soft prompt or the system dialog and never writes cooldown state, so it is
  /// safe to call on screen mount or app resume to reconcile UI state.
  Future<NotificationPermissionStatus> permissionStatus() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    return _toStatus(settings.authorizationStatus);
  }

  static NotificationPermissionStatus _toStatus(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return NotificationPermissionStatus.authorized;
      case AuthorizationStatus.denied:
        return NotificationPermissionStatus.denied;
      case AuthorizationStatus.notDetermined:
        return NotificationPermissionStatus.notDetermined;
    }
  }

  /// Returns the FCM token for this device.
  Future<String?> getToken() {
    return _firebaseMessaging.getToken();
  }

  /// Stream of FCM tokens.
  Stream<String> get onTokenRefresh => _firebaseMessaging.onTokenRefresh;

  /// Posts a device-local notification with the given [title]/[body] —
  /// distinct from the FCM-permission flows above, this never touches the
  /// network: it's for surfacing something that already happened locally
  /// (e.g. an imported review-sync bundle) rather than a remote push.
  ///
  /// Never throws: plugin failures are mapped to a
  /// [LocalNotificationException] inside a [ResultFailure], the same
  /// pattern `services/networking` uses for `DioException`.
  Future<Result<void>> showLocal({
    required String title,
    required String body,
  }) => Result.guard<void>(() async {
    try {
      await _localNotifications.show(
        id: _nextNotificationId(),
        title: title,
        body: body,
      );
    } on Object catch (error) {
      throw LocalNotificationException(
        'Failed to show local notification: $error',
      );
    }
  });

  // A distinct id per call so successive local notifications (e.g. two
  // review-sync imports in a row) each stay visible instead of the plugin
  // treating them as updates to the same notification. Truncated to fit
  // `flutter_local_notifications`' platform-imposed 32-bit signed int id.
  int _nextNotificationId() =>
      DateTime.now().microsecondsSinceEpoch.remainder(1 << 31);

  bool _canShowSoftPrompt() {
    final lastDeclined = _prefs.getInt(_kSoftPromptDeclinedKey);
    if (lastDeclined == null) return true;

    final lastDeclinedDate = DateTime.fromMillisecondsSinceEpoch(lastDeclined);
    final difference = DateTime.now().difference(lastDeclinedDate).inDays;

    return difference >= _kSoftPromptCooldownDays;
  }

  Future<void> _markSoftPromptDeclined() async {
    await _prefs.setInt(
      _kSoftPromptDeclinedKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
