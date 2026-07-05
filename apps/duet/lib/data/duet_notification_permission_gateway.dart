import 'package:core_utils/core_utils.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:notifications/notifications.dart';

/// A [NotificationPermissionGateway] backed by the real
/// `NotificationsManager` — per that gateway's own doc: [currentStatus] maps
/// `NotificationsManager.permissionStatus()` (the side-effect-free read) and
/// [ensurePermission] delegates to `NotificationsManager.requestPermission`.
class DuetNotificationPermissionGateway
    implements NotificationPermissionGateway {
  /// Creates a [DuetNotificationPermissionGateway] wrapping a
  /// `NotificationsManager`. [deviceTokenSync], if given, has
  /// `registerCurrent()` invoked right after a successful grant (FIX-7):
  /// `NotificationsManager.requestPermission` only ever returns a `bool`,
  /// so there's no permission-grant *stream* to subscribe to instead — this
  /// call site has to register explicitly.
  const DuetNotificationPermissionGateway(
    this._manager, {
    DeviceTokenSync? deviceTokenSync,
  }) : _deviceTokenSync = deviceTokenSync;

  final NotificationsManager _manager;
  final DeviceTokenSync? _deviceTokenSync;

  @override
  Future<Result<NotificationPermission>> currentStatus() =>
      Result.guard<NotificationPermission>(() async {
        return _toPermission(await _manager.permissionStatus());
      });

  @override
  Future<Result<NotificationPermission>> ensurePermission({
    BuildContext? context,
  }) => Result.guard<NotificationPermission>(() async {
    await _manager.requestPermission(context: context);
    // `requestPermission` only returns a bool, collapsing "denied" and
    // "permanently denied" into a single `false`; re-reading the
    // side-effect-free status afterwards recovers the precise result the
    // gateway contract needs.
    final permission = _toPermission(await _manager.permissionStatus());
    if (permission == NotificationPermission.granted) {
      await _deviceTokenSync?.registerCurrent();
    }
    return permission;
  });

  @override
  Future<Result<void>> openSystemSettings() async {
    // `NotificationsManager` has no OS-settings launcher yet (there's no
    // cross-platform "open this app's notification settings" capability
    // wired anywhere in the factory) — a documented, tracked gap rather than
    // a fabricated success. The blocked-state escape hatch this backs (see
    // `SettingsScreen`'s "Open settings" button) is unreachable in this
    // MVP's simulated permission flow anyway, since `MockAuthRepository`-style
    // local dev never actually reaches the OS's permanently-denied state.
    return ResultFailure<void>(
      UnsupportedError(
        'Opening OS notification settings is not implemented yet',
      ),
    );
  }

  NotificationPermission _toPermission(NotificationPermissionStatus status) {
    switch (status) {
      case NotificationPermissionStatus.authorized:
        return NotificationPermission.granted;
      case NotificationPermissionStatus.denied:
        return NotificationPermission.permanentlyDenied;
      case NotificationPermissionStatus.notDetermined:
        return NotificationPermission.denied;
    }
  }
}
