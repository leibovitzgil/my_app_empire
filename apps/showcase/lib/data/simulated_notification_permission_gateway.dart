import 'package:core_utils/core_utils.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/widgets.dart';

/// A [NotificationPermissionGateway] that simulates the permission flow so the
/// showcase runs without Firebase. Mirrors the mock/simulated backends used
/// elsewhere in the showcase (e.g. the mock auth repository).
///
/// Starts denied; the first [ensurePermission] "grants" it. There is no
/// permanently-denied path in the simulation — that case is exercised by the
/// feature's unit tests against a mock gateway.
class SimulatedNotificationPermissionGateway
    implements NotificationPermissionGateway {
  NotificationPermission _status = NotificationPermission.denied;

  @override
  Future<Result<NotificationPermission>> currentStatus() async =>
      Success<NotificationPermission>(_status);

  @override
  Future<Result<NotificationPermission>> ensurePermission({
    BuildContext? context,
  }) async {
    _status = NotificationPermission.granted;
    return Success<NotificationPermission>(_status);
  }

  @override
  Future<Result<void>> openSystemSettings() async => const Success<void>(null);
}
