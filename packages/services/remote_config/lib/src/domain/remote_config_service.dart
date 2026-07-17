/// The remote-config key names and their committed code defaults.
///
/// The defaults here are the single source of truth for what every flag
/// means when no remote value has ever been fetched (fresh install,
/// offline first run, fetch failure, or the in-memory fake): the Firebase
/// implementation feeds [defaults] to `setDefaults`, and the in-memory
/// fake seeds itself from the same map. Kill-switches default to
/// **enabled** — flipping one off in the console is the emergency action,
/// so the committed default must be the healthy state.
abstract final class RemoteConfigKeys {
  /// Whether onboarding should end on the paywall.
  static const String showPaywallOnOnboarding = 'show_paywall_on_onboarding';

  /// Whether the app is in maintenance mode.
  static const String maintenanceMode = 'maintenance_mode';

  /// The minimum supported app version.
  static const String minSupportedVersion = 'min_supported_version';

  /// Kill-switch: whether the paywall may be shown at all.
  static const String paywallEnabled = 'paywall_enabled';

  /// Kill-switch: whether tokenized invite links may be created/shared.
  static const String inviteLinksEnabled = 'invite_links_enabled';

  /// Opaque pricing-experiment variant (offering selection); empty means
  /// the default offering.
  static const String pricingExperiment = 'pricing_experiment';

  /// The committed code defaults, keyed by remote-config key name.
  static const Map<String, Object> defaults = <String, Object>{
    showPaywallOnOnboarding: false,
    maintenanceMode: false,
    minSupportedVersion: '0.0.0',
    paywallEnabled: true,
    inviteLinksEnabled: true,
    pricingExperiment: '',
  };
}

/// Contract for typed access to remotely-configurable flags.
///
/// Consumers (blocs, UI seams, app wiring) depend on this contract only —
/// never on `FirebaseRemoteConfig` directly — so the headless/mock
/// composition can bind the in-memory fake and tests can seed exactly
/// the flag values they need.
///
/// Failure model: remote config is deliberately *not* `Result`-shaped.
/// A failed fetch is never a blocking error the UI should render — the
/// committed defaults in [RemoteConfigKeys.defaults] (or the last
/// activated values) simply remain in effect, so [init] and [refresh]
/// complete normally on fetch failure and the typed getters always
/// return a usable value synchronously.
abstract class RemoteConfigService {
  /// Prepares the service: installs the committed defaults and attempts a
  /// first fetch+activate. Safe to call in any composition; never throws
  /// on fetch failure (defaults remain in effect).
  Future<void> init();

  /// Attempts to fetch and activate fresh values. Never throws on fetch
  /// failure — the previously activated values (or defaults) remain.
  Future<void> refresh();

  /// Whether onboarding should end on the paywall.
  bool get showPaywallOnOnboarding;

  /// Whether the app is in maintenance mode.
  bool get maintenanceMode;

  /// The minimum supported app version.
  String get minSupportedVersion;

  /// Kill-switch: whether the paywall may be shown at all.
  bool get paywallEnabled;

  /// Kill-switch: whether tokenized invite links may be created/shared.
  bool get inviteLinksEnabled;

  /// Opaque pricing-experiment variant (offering selection); empty means
  /// the default offering.
  String get pricingExperiment;
}
