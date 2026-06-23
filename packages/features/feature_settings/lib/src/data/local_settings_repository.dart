import 'package:core_utils/core_utils.dart';
import 'package:feature_settings/src/domain/settings_repository.dart';
import 'package:local_storage/local_storage.dart';

/// A [SettingsRepository] backed by [LocalStorageService] (shared prefs).
class LocalSettingsRepository implements SettingsRepository {
  /// Creates a repository persisting via the given storage service.
  LocalSettingsRepository(this._storage);

  static const String _kPushEnabledKey = 'settings_push_enabled';

  final LocalStorageService _storage;

  @override
  Future<Result<bool>> readPushEnabled() =>
      Result.guard(() async => _storage.getBool(_kPushEnabledKey) ?? false);

  @override
  Future<Result<void>> writePushEnabled(bool enabled) => Result.guard(() async {
    await _storage.setBool(_kPushEnabledKey, enabled);
  });
}
