import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:remote_config/src/domain/remote_config_service.dart';

/// A [RemoteConfigService] backed by [FirebaseRemoteConfig].
///
/// Requires `Firebase.initializeApp` to have completed before construction
/// (the default constructor reaches for `FirebaseRemoteConfig.instance`),
/// so only real-Firebase compositions may bind it — never the headless
/// default gate.
class FirebaseRemoteConfigService implements RemoteConfigService {
  /// Creates a [FirebaseRemoteConfigService] over [remoteConfig]
  /// (defaulting to [FirebaseRemoteConfig.instance]).
  FirebaseRemoteConfigService({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;

  @override
  Future<void> init() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode
            ? const Duration(minutes: 5)
            : const Duration(hours: 12),
      ),
    );
    await _remoteConfig.setDefaults(RemoteConfigKeys.defaults);
    await refresh();
  }

  @override
  Future<void> refresh() async {
    try {
      await _remoteConfig.fetchAndActivate();
    } on Object {
      // Ignored by design: the committed defaults (or the last activated
      // values) remain in effect if the fetch fails.
    }
  }

  @override
  bool get showPaywallOnOnboarding =>
      _remoteConfig.getBool(RemoteConfigKeys.showPaywallOnOnboarding);

  @override
  bool get maintenanceMode =>
      _remoteConfig.getBool(RemoteConfigKeys.maintenanceMode);

  @override
  String get minSupportedVersion =>
      _remoteConfig.getString(RemoteConfigKeys.minSupportedVersion);

  @override
  String get storeUrl => _remoteConfig.getString(RemoteConfigKeys.storeUrl);

  @override
  bool get paywallEnabled =>
      _remoteConfig.getBool(RemoteConfigKeys.paywallEnabled);

  @override
  bool get inviteLinksEnabled =>
      _remoteConfig.getBool(RemoteConfigKeys.inviteLinksEnabled);

  @override
  String get pricingExperiment =>
      _remoteConfig.getString(RemoteConfigKeys.pricingExperiment);
}
