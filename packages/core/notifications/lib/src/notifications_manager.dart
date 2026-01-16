import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/soft_prompt_dialog.dart';

class NotificationsManager {
  static const String _kSoftPromptDeclinedKey = 'notifications_soft_prompt_declined_timestamp';
  // Cooldown in days before showing soft prompt again
  static const int _kSoftPromptCooldownDays = 7;

  final FirebaseMessaging _firebaseMessaging;
  final SharedPreferences _prefs;

  NotificationsManager(this._firebaseMessaging, this._prefs);

  /// Creates a [NotificationsManager] with default dependencies.
  static Future<NotificationsManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationsManager(FirebaseMessaging.instance, prefs);
  }

  /// Request permission for notifications.
  ///
  /// Returns [true] if permission is granted (or provisional).
  ///
  /// [useSoftPrompt] if true, will show a dialog explaining why notifications are needed
  /// before requesting system permission. This is highly recommended for iOS and Android 13+.
  ///
  /// [context] is required if [useSoftPrompt] is true.
  Future<bool> requestPermission({
    BuildContext? context,
    bool useSoftPrompt = true,
  }) async {
    // 1. Check current status
    final settings = await _firebaseMessaging.getNotificationSettings();

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      return true;
    }

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
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

      final bool userAgreed = await showDialog<bool>(
        context: context,
        builder: (ctx) => SoftPromptDialog(
          onAllow: () => Navigator.of(ctx).pop(true),
          onLater: () => Navigator.of(ctx).pop(false),
        ),
      ) ?? false;

      if (!userAgreed) {
        await _markSoftPromptDeclined();
        return false;
      }
    }

    // User agreed or soft prompt disabled/not possible.
    final newSettings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    return newSettings.authorizationStatus == AuthorizationStatus.authorized ||
        newSettings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Returns the FCM token for this device.
  Future<String?> getToken() {
    return _firebaseMessaging.getToken();
  }

  /// Stream of FCM tokens.
  Stream<String> get onTokenRefresh => _firebaseMessaging.onTokenRefresh;

  bool _canShowSoftPrompt() {
    final int? lastDeclined = _prefs.getInt(_kSoftPromptDeclinedKey);
    if (lastDeclined == null) return true;

    final lastDeclinedDate = DateTime.fromMillisecondsSinceEpoch(lastDeclined);
    final difference = DateTime.now().difference(lastDeclinedDate).inDays;

    return difference >= _kSoftPromptCooldownDays;
  }

  Future<void> _markSoftPromptDeclined() async {
    await _prefs.setInt(_kSoftPromptDeclinedKey, DateTime.now().millisecondsSinceEpoch);
  }
}
