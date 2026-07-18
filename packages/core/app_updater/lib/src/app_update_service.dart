import 'package:package_info_plus/package_info_plus.dart';
import 'package:remote_config/remote_config.dart';

/// Decides whether the running app version is below the remotely-configured
/// minimum ([RemoteConfigKeys.minSupportedVersion]) and where to send the
/// user to update ([RemoteConfigKeys.storeUrl]).
///
/// Consumes the [RemoteConfigService] contract — never a Firebase instance
/// of its own — so every app shares one config pipeline and tests seed an
/// `InMemoryRemoteConfigService` with exactly the versions they need.
class AppUpdateService {
  /// Creates an [AppUpdateService] over [remoteConfig].
  ///
  /// [currentVersion] resolves the running app's version string and defaults
  /// to `package_info_plus`; tests inject a fixed value instead.
  AppUpdateService({
    required RemoteConfigService remoteConfig,
    Future<String> Function()? currentVersion,
  }) : _remoteConfig = remoteConfig,
       _currentVersion = currentVersion ?? _platformVersion;

  final RemoteConfigService _remoteConfig;
  final Future<String> Function() _currentVersion;

  static Future<String> _platformVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  /// Whether the current app version is below the remote minimum.
  ///
  /// Fails open — an empty configured minimum, a failed refresh (the
  /// contract never throws on fetch failure; the committed defaults
  /// remain in effect), or an unreadable current version (e.g. headless
  /// tests, where the platform channel is absent) all mean "don't block".
  Future<bool> isUpdateRequired() async {
    await _remoteConfig.refresh();
    final minVersion = _remoteConfig.minSupportedVersion;
    if (minVersion.isEmpty) {
      return false;
    }

    final String currentVersion;
    try {
      currentVersion = await _currentVersion();
    } on Object {
      // Can't determine the running version — never block on a guess.
      return false;
    }

    return _isVersionBelowMin(currentVersion, minVersion);
  }

  /// The store listing to send the user to; empty when not configured.
  String getStoreUrl() => _remoteConfig.storeUrl;

  bool _isVersionBelowMin(String current, String min) {
    final currentParts = current
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final minParts = min.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final length = currentParts.length > minParts.length
        ? currentParts.length
        : minParts.length;

    for (var i = 0; i < length; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final minPart = i < minParts.length ? minParts[i] : 0;

      if (currentPart < minPart) {
        return true;
      }
      if (currentPart > minPart) {
        return false;
      }
    }
    return false;
  }
}
