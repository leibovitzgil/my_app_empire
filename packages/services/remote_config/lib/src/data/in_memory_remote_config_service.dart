import 'package:remote_config/src/domain/remote_config_service.dart';

/// A [RemoteConfigService] backed by an in-memory map. The default-gate
/// (headless, no-Firebase) fake: every key starts at its committed code
/// default ([RemoteConfigKeys.defaults]); seed the constructor's
/// `overrides` with whichever flag values a test/app run needs.
///
/// [init] and [refresh] are no-ops — the seeded values *are* the "fetched"
/// values for the lifetime of the instance.
class InMemoryRemoteConfigService implements RemoteConfigService {
  /// Creates an [InMemoryRemoteConfigService] seeded with
  /// [RemoteConfigKeys.defaults], with [overrides] layered on top.
  InMemoryRemoteConfigService({Map<String, Object> overrides = const {}})
    : _values = <String, Object>{...RemoteConfigKeys.defaults, ...overrides};

  final Map<String, Object> _values;

  @override
  Future<void> init() async {}

  @override
  Future<void> refresh() async {}

  @override
  bool get showPaywallOnOnboarding =>
      _values[RemoteConfigKeys.showPaywallOnOnboarding]! as bool;

  @override
  bool get maintenanceMode =>
      _values[RemoteConfigKeys.maintenanceMode]! as bool;

  @override
  String get minSupportedVersion =>
      _values[RemoteConfigKeys.minSupportedVersion]! as String;

  @override
  String get storeUrl => _values[RemoteConfigKeys.storeUrl]! as String;

  @override
  bool get paywallEnabled => _values[RemoteConfigKeys.paywallEnabled]! as bool;

  @override
  bool get inviteLinksEnabled =>
      _values[RemoteConfigKeys.inviteLinksEnabled]! as bool;

  @override
  String get pricingExperiment =>
      _values[RemoteConfigKeys.pricingExperiment]! as String;
}
