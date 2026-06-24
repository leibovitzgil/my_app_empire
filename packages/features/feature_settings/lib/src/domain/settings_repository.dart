import 'package:core_utils/core_utils.dart';

/// Contract for persisting user-facing app settings.
abstract class SettingsRepository {
  /// Reads whether push notifications are enabled. Defaults to `false`.
  Future<Result<bool>> readPushEnabled();

  /// Persists whether push notifications are enabled.
  Future<Result<void>> writePushEnabled(bool enabled);
}
