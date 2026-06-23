part of 'settings_bloc.dart';

/// The lifecycle of the settings screen.
enum SettingsStatus {
  /// Initial load of persisted prefs + permission is in flight.
  loading,

  /// Settings are loaded and idle.
  loaded,

  /// A toggle is awaiting a permission decision.
  pending,

  /// Push is permanently denied by the OS; the user must open system settings.
  blocked,

  /// The last operation failed; [SettingsState.error] explains.
  failure,
}

final class SettingsState extends Equatable {
  const SettingsState._({
    required this.status,
    this.pushEnabled = false,
    this.lastKnownGood = false,
    this.error,
  });

  const SettingsState.loading() : this._(status: SettingsStatus.loading);

  const SettingsState.loaded({required bool pushEnabled})
    : this._(
        status: SettingsStatus.loaded,
        pushEnabled: pushEnabled,
        lastKnownGood: pushEnabled,
      );

  const SettingsState.pending({required bool pushEnabled})
    : this._(
        status: SettingsStatus.pending,
        pushEnabled: pushEnabled,
        lastKnownGood: pushEnabled,
      );

  const SettingsState.blocked() : this._(status: SettingsStatus.blocked);

  const SettingsState.failure(String error, {required bool pushEnabled})
    : this._(
        status: SettingsStatus.failure,
        pushEnabled: pushEnabled,
        lastKnownGood: pushEnabled,
        error: error,
      );

  /// The current lifecycle status.
  final SettingsStatus status;

  /// Whether the toggle should read as on.
  final bool pushEnabled;

  /// The last value known to be both persisted and permitted, used to revert.
  final bool lastKnownGood;

  /// A human-readable error for [SettingsStatus.failure].
  final String? error;

  @override
  List<Object?> get props => [status, pushEnabled, lastKnownGood, error];
}
