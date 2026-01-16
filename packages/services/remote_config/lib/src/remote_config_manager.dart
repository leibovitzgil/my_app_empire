import 'dart:async';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Wrapper around [FirebaseRemoteConfig] to provide typed access to config values.
class RemoteConfigManager {
  RemoteConfigManager({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;

  static const String _showPaywallOnOnboardingKey =
      'show_paywall_on_onboarding';
  static const String _maintenanceModeKey = 'maintenance_mode';
  static const String _minSupportedVersionKey = 'min_supported_version';

  /// Initializes the Remote Config with default values and fetches settings.
  Future<void> init() async {
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval:
          kDebugMode ? const Duration(minutes: 5) : const Duration(hours: 12),
    ));

    await _remoteConfig.setDefaults({
      _showPaywallOnOnboardingKey: false,
      _maintenanceModeKey: false,
      _minSupportedVersionKey: '0.0.0',
    });

    try {
      await _remoteConfig.fetchAndActivate();
    } catch (_) {
      // Ignored: Default values will be used if fetch fails.
    }
  }

  /// Whether to show the paywall during onboarding.
  bool get showPaywallOnOnboarding =>
      _remoteConfig.getBool(_showPaywallOnOnboardingKey);

  /// Whether the app is in maintenance mode.
  bool get maintenanceMode => _remoteConfig.getBool(_maintenanceModeKey);

  /// The minimum supported app version.
  String get minSupportedVersion =>
      _remoteConfig.getString(_minSupportedVersionKey);
}
