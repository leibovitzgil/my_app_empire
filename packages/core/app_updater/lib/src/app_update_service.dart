import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateService {
  AppUpdateService({
    FirebaseRemoteConfig? remoteConfig,
  }) : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;

  static const String _minSupportedVersionKey = 'min_supported_version';
  static const String _storeUrlKey = 'store_url';

  Future<bool> isUpdateRequired() async {
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      // In case of error (e.g. offline), we don't force update.
      return false;
    }

    final minVersionString = _remoteConfig.getString(_minSupportedVersionKey);
    if (minVersionString.isEmpty) {
      return false;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersionString = packageInfo.version;

    return _isVersionBelowMin(currentVersionString, minVersionString);
  }

  String getStoreUrl() {
    return _remoteConfig.getString(_storeUrlKey);
  }

  bool _isVersionBelowMin(String current, String min) {
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final minParts = min.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final length = currentParts.length > minParts.length ? currentParts.length : minParts.length;

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
