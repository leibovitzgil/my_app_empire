import 'package:core_utils/core_utils.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:notifications/notifications.dart';

/// A [SettingsRepository] that persists the push preference locally (via
/// [_delegate], the generic `LocalSettingsRepository`) AND mirrors it onto
/// `deviceTokens/{uid}.pushEnabled` through the [DeviceTokenRegistry], so
/// Duet's digest-drain Function (M5.4) can skip a muted recipient.
///
/// This is Duet **glue**, deliberately not in `feature_settings`: that
/// package stays backend-agnostic (G3) — it knows nothing of device tokens
/// or push fan-out. The mirror is the app-specific bridge between the
/// client-side toggle and the server-side sender, exactly like
/// `DuetNotificationPermissionGateway` bridges the toggle to token
/// registration.
///
/// The local write is authoritative for what the toggle *shows*: if it
/// fails, the whole call fails (the UI must not claim a state that wasn't
/// persisted). The mirror is **best-effort** on top of a successful local
/// write — a mirror hiccup (offline, no signed-in uid) must not flip the
/// toggle back, and the next toggle (or a token re-registration) re-asserts
/// it. A signed-out uid (`''`) is skipped: there's no `deviceTokens` doc to
/// mirror onto until login, and `DeviceTokenSync` re-registers this device
/// then.
class MirroringSettingsRepository implements SettingsRepository {
  /// Creates a [MirroringSettingsRepository] wrapping [delegate], mirroring
  /// through [registry] for the uid [currentUserId] resolves at write time.
  MirroringSettingsRepository({
    required SettingsRepository delegate,
    required DeviceTokenRegistry registry,
    required String Function() currentUserId,
  }) : _delegate = delegate,
       _registry = registry,
       _currentUserId = currentUserId;

  final SettingsRepository _delegate;
  final DeviceTokenRegistry _registry;
  final String Function() _currentUserId;

  @override
  Future<Result<bool>> readPushEnabled() => _delegate.readPushEnabled();

  @override
  Future<Result<void>> writePushEnabled(bool enabled) async {
    final written = await _delegate.writePushEnabled(enabled);
    if (written is ResultFailure<void>) return written;
    final uid = _currentUserId();
    if (uid.isNotEmpty) {
      // Best-effort: a failed mirror never fails the authoritative local
      // write (the toggle's source of truth); the result is intentionally
      // discarded.
      await _registry.setPushEnabled(uid, enabled: enabled);
    }
    return written;
  }
}
