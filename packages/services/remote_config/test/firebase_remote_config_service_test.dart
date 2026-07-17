import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_config/remote_config.dart';

class FakeFirebaseRemoteConfig extends Fake implements FirebaseRemoteConfig {
  final Map<String, dynamic> _defaults = {};
  final Map<String, dynamic> _values = {};

  bool throwOnFetch = false;
  int fetchCount = 0;

  @override
  Future<void> setConfigSettings(
    RemoteConfigSettings remoteConfigSettings,
  ) async {}

  @override
  Future<void> setDefaults(Map<String, dynamic> defaultParameters) async {
    _defaults.addAll(defaultParameters);
  }

  @override
  Future<bool> fetchAndActivate() async {
    fetchCount++;
    if (throwOnFetch) throw Exception('offline');
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
  group('FirebaseRemoteConfigService', () {
    late FakeFirebaseRemoteConfig fakeRemoteConfig;
    late FirebaseRemoteConfigService service;

    setUp(() {
      fakeRemoteConfig = FakeFirebaseRemoteConfig();
      service = FirebaseRemoteConfigService(remoteConfig: fakeRemoteConfig);
    });

    test('init installs the committed defaults and fetches once', () async {
      await service.init();

      expect(fakeRemoteConfig.fetchCount, 1);
      expect(service.showPaywallOnOnboarding, isFalse);
      expect(service.maintenanceMode, isFalse);
      expect(service.minSupportedVersion, '0.0.0');
      expect(service.paywallEnabled, isTrue);
      expect(service.inviteLinksEnabled, isTrue);
      expect(service.pricingExperiment, isEmpty);
    });

    test('remote values win over defaults once activated', () async {
      fakeRemoteConfig
        ..setVal(RemoteConfigKeys.showPaywallOnOnboarding, true)
        ..setVal(RemoteConfigKeys.maintenanceMode, true)
        ..setVal(RemoteConfigKeys.minSupportedVersion, '1.2.3')
        ..setVal(RemoteConfigKeys.paywallEnabled, false)
        ..setVal(RemoteConfigKeys.inviteLinksEnabled, false)
        ..setVal(RemoteConfigKeys.pricingExperiment, 'variant_b');

      await service.init();

      expect(service.showPaywallOnOnboarding, isTrue);
      expect(service.maintenanceMode, isTrue);
      expect(service.minSupportedVersion, '1.2.3');
      expect(service.paywallEnabled, isFalse);
      expect(service.inviteLinksEnabled, isFalse);
      expect(service.pricingExperiment, 'variant_b');
    });

    test(
      'a failed fetch never throws — the committed defaults remain',
      () async {
        fakeRemoteConfig.throwOnFetch = true;

        await service.init();
        await service.refresh();

        expect(service.inviteLinksEnabled, isTrue);
        expect(service.minSupportedVersion, '0.0.0');
      },
    );

    test('refresh fetches again', () async {
      await service.init();
      await service.refresh();

      expect(fakeRemoteConfig.fetchCount, 2);
    });
  });
}
