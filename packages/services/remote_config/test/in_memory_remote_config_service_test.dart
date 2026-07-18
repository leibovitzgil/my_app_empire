import 'package:flutter_test/flutter_test.dart';
import 'package:remote_config/remote_config.dart';

void main() {
  group('InMemoryRemoteConfigService', () {
    test('exposes the committed code defaults unseeded', () {
      final service = InMemoryRemoteConfigService();

      expect(service.showPaywallOnOnboarding, isFalse);
      expect(service.maintenanceMode, isFalse);
      expect(service.minSupportedVersion, '0.0.0');
      expect(service.storeUrl, isEmpty);
      // Kill-switches default to enabled: flipping one off in the console
      // is the emergency action, so the committed default is the healthy
      // state.
      expect(service.paywallEnabled, isTrue);
      expect(service.inviteLinksEnabled, isTrue);
      expect(service.pricingExperiment, isEmpty);
    });

    test('constructor-seeded overrides win over defaults', () {
      final service = InMemoryRemoteConfigService(
        overrides: const {
          RemoteConfigKeys.inviteLinksEnabled: false,
          RemoteConfigKeys.pricingExperiment: 'variant_b',
        },
      );

      expect(service.inviteLinksEnabled, isFalse);
      expect(service.pricingExperiment, 'variant_b');
      // Unseeded keys keep their defaults.
      expect(service.paywallEnabled, isTrue);
      expect(service.maintenanceMode, isFalse);
    });

    test('init and refresh are no-ops that keep seeded values', () async {
      final service = InMemoryRemoteConfigService(
        overrides: const {RemoteConfigKeys.paywallEnabled: false},
      );

      await service.init();
      await service.refresh();

      expect(service.paywallEnabled, isFalse);
    });
  });
}
