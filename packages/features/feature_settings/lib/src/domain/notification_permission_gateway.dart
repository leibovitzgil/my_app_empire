import 'package:core_utils/core_utils.dart';
import 'package:flutter/widgets.dart';

/// The effective notification permission, as seen by the settings feature.
enum NotificationPermission {
  /// The user has granted (or provisionally granted) permission.
  granted,

  /// Permission is not granted but can still be requested.
  denied,

  /// Permission is denied and the OS will no longer show a prompt; the user
  /// must change it from system settings.
  permanentlyDenied,
}

/// A port the settings feature depends on to reason about notification
/// permission without coupling to a concrete push backend.
///
/// Deliberately separates a side-effect-free read ([currentStatus]) from the
/// prompting flow ([ensurePermission]) so the UI can reconcile state on mount
/// and resume without ever triggering a system prompt.
///
/// A production app backs this with `services/notifications`:
/// [currentStatus] maps `NotificationsManager.permissionStatus()` (the
/// side-effect-free read) and [ensurePermission] delegates to
/// `NotificationsManager.requestPermission(...)`. The showcase binds a
/// simulated gateway instead, since it runs without Firebase.
abstract class NotificationPermissionGateway {
  /// Reads the current permission without prompting the user.
  Future<Result<NotificationPermission>> currentStatus();

  /// Ensures permission, prompting the user if needed. [context] enables a
  /// soft-prompt explanation before the system dialog.
  Future<Result<NotificationPermission>> ensurePermission({
    BuildContext? context,
  });

  /// Opens the OS notification settings for this app.
  Future<Result<void>> openSystemSettings();
}
