import 'package:core_utils/core_utils.dart';

/// Contract for registering/unregistering a device's push token against a
/// user, so a server-side sender knows which devices to notify. The reader
/// this registry provisions is Duet's `onInboxMessageCreated` Cloud Function
/// (M5.3): it fans each `userInbox` write out over FCM to the registered
/// tokens and prunes any token FCM reports as no longer registered — exactly
/// the consume-unchanged path this write-only client plumbing anticipated.
abstract class DeviceTokenRegistry {
  /// Registers [token] as a current push token for [uid]. Idempotent:
  /// registering the same token again is a no-op.
  Future<Result<void>> register(String uid, String token);

  /// Unregisters [token] for [uid] (e.g. on sign-out). Idempotent: a no-op
  /// if [token] isn't currently registered.
  Future<Result<void>> unregister(String uid, String token);

  /// Mirrors [uid]'s push preference onto `deviceTokens/{uid}.pushEnabled`,
  /// so a server-side sender can honor the client's Settings toggle. The
  /// preference itself lives client-side (`SettingsRepository`); this write
  /// is the seam that lets Duet's digest-drain Function (M5.4) skip a muted
  /// recipient. A no-op field-merge that leaves the token list untouched.
  Future<Result<void>> setPushEnabled(String uid, {required bool enabled});
}
