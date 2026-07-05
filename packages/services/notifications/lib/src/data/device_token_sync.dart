import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:notifications/src/domain/device_token_registry.dart';

/// Coordinates keeping [DeviceTokenRegistry] in sync with this device's
/// current push token, for the current user.
///
/// Both its token source and its current-user id are INJECTED (FIX-3) —
/// this class never reaches for `NotificationsManager`/`FirebaseMessaging`
/// itself. That keeps the default (`useFirebase:false`) DI branch able to
/// bind it against a fake token source (a seeded `StreamController`/stub),
/// so nothing resolves real messaging plumbing in the headless test gate.
/// Only the `useFirebase:true` branch binds `tokenGetter`/`onTokenRefresh`
/// to `NotificationsManager.getToken`/`onTokenRefresh`.
class DeviceTokenSync {
  /// Creates a [DeviceTokenSync]. [onTokenRefresh] is subscribed
  /// immediately, so a token rotation re-registers for as long as this
  /// instance is alive; call [dispose] to cancel that subscription.
  DeviceTokenSync({
    required DeviceTokenRegistry registry,
    required String Function() currentUserId,
    required Future<String?> Function() tokenGetter,
    required Stream<String> onTokenRefresh,
  }) : _registry = registry,
       _currentUserId = currentUserId,
       _tokenGetter = tokenGetter {
    _refreshSubscription = onTokenRefresh.listen(_register);
  }

  final DeviceTokenRegistry _registry;
  final String Function() _currentUserId;
  final Future<String?> Function() _tokenGetter;
  late final StreamSubscription<String> _refreshSubscription;

  /// Registers this device's current token immediately.
  ///
  /// There is no permission-GRANT stream to subscribe to instead (FIX-7):
  /// `NotificationsManager.requestPermission` just returns a `bool`, so the
  /// notification-permission call site (e.g. a Settings toggle, or the
  /// soft-prompt flow) must call this explicitly right after a grant. A
  /// no-op (never fails) if `tokenGetter` resolves `null` — e.g. the
  /// platform hasn't yet assigned one.
  Future<Result<void>> registerCurrent() => Result.guard<void>(() async {
    final token = await _tokenGetter();
    if (token == null) return;
    await _register(token);
  });

  Future<void> _register(String token) async {
    await _registry.register(_currentUserId(), token);
  }

  /// Cancels the token-refresh subscription. Call when the owning scope
  /// (e.g. the app's DI container) is torn down.
  Future<void> dispose() => _refreshSubscription.cancel();
}
