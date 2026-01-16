import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:remote_config/remote_config.dart';

class FakeFirebaseRemoteConfig extends Fake implements FirebaseRemoteConfig {
  final Map<String, dynamic> _defaults = {};
  final Map<String, dynamic> _values = {};

  @override
  Future<void> setConfigSettings(RemoteConfigSettings remoteConfigSettings) async {}

  @override
  Future<void> setDefaults(Map<String, dynamic> defaultParameters) async {
    _defaults.addAll(defaultParameters);
  }

  @override
  Future<bool> fetchAndActivate() async {
    return true;
  }

  @override
  bool getBool(String key) {
    if (_values.containsKey(key)) return _values[key] as bool;
    if (_defaults.containsKey(key)) return _defaults[key] as bool;
    return false; // Fallback
  }

  @override
  String getString(String key) {
    if (_values.containsKey(key)) return _values[key] as String;
    if (_defaults.containsKey(key)) return _defaults[key] as String;
    return ''; // Fallback
  }

  void setVal(String key, dynamic value) {
    _values[key] = value;
  }
}

void main() {
  group('RemoteConfigManager', () {
    late FakeFirebaseRemoteConfig fakeRemoteConfig;
    late RemoteConfigManager manager;

    setUp(() {
      fakeRemoteConfig = FakeFirebaseRemoteConfig();
      manager = RemoteConfigManager(remoteConfig: fakeRemoteConfig);
    });

    test('defaults are set correctly', () async {
      await manager.init();
      // Keys matching the implementation
      expect(fakeRemoteConfig.getBool('show_paywall_on_onboarding'), false);
      expect(fakeRemoteConfig.getBool('maintenance_mode'), false);
      expect(fakeRemoteConfig.getString('min_supported_version'), '0.0.0');

      // Access via manager
      expect(manager.showPaywallOnOnboarding, false);
      expect(manager.maintenanceMode, false);
      expect(manager.minSupportedVersion, '0.0.0');
    });

    test('values are retrieved from remote config', () async {
      fakeRemoteConfig.setVal('show_paywall_on_onboarding', true);
      fakeRemoteConfig.setVal('maintenance_mode', true);
      fakeRemoteConfig.setVal('min_supported_version', '1.2.3');

      await manager.init();

      expect(manager.showPaywallOnOnboarding, true);
      expect(manager.maintenanceMode, true);
      expect(manager.minSupportedVersion, '1.2.3');
    });
  });
}
