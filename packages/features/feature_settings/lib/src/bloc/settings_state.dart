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

/// The lifecycle of the "Restore purchases" action.
enum SettingsRestoreStatus {
  /// No restore attempt in flight.
  idle,

  /// A restore is in progress.
  restoring,

  /// The most recent restore found and applied an active purchase.
  success,

  /// The most recent restore failed or found nothing to restore.
  failure,
}

final class SettingsState extends Equatable {
  const SettingsState._({
    required this.status,
    this.pushEnabled = false,
    this.lastKnownGood = false,
    this.error,
    this.restoreStatus = SettingsRestoreStatus.idle,
    this.restoreError,
  });

  const SettingsState.loading({
    SettingsRestoreStatus restoreStatus = SettingsRestoreStatus.idle,
    String? restoreError,
  }) : this._(
         status: SettingsStatus.loading,
         restoreStatus: restoreStatus,
         restoreError: restoreError,
       );

  const SettingsState.loaded({
    required bool pushEnabled,
    SettingsRestoreStatus restoreStatus = SettingsRestoreStatus.idle,
    String? restoreError,
  }) : this._(
         status: SettingsStatus.loaded,
         pushEnabled: pushEnabled,
         lastKnownGood: pushEnabled,
         restoreStatus: restoreStatus,
         restoreError: restoreError,
       );

  const SettingsState.pending({
    required bool pushEnabled,
    SettingsRestoreStatus restoreStatus = SettingsRestoreStatus.idle,
    String? restoreError,
  }) : this._(
         status: SettingsStatus.pending,
         pushEnabled: pushEnabled,
         lastKnownGood: pushEnabled,
         restoreStatus: restoreStatus,
         restoreError: restoreError,
       );

  const SettingsState.blocked({
    SettingsRestoreStatus restoreStatus = SettingsRestoreStatus.idle,
    String? restoreError,
  }) : this._(
         status: SettingsStatus.blocked,
         restoreStatus: restoreStatus,
         restoreError: restoreError,
       );

  const SettingsState.failure(
    String error, {
    required bool pushEnabled,
    SettingsRestoreStatus restoreStatus = SettingsRestoreStatus.idle,
    String? restoreError,
  }) : this._(
         status: SettingsStatus.failure,
         pushEnabled: pushEnabled,
         lastKnownGood: pushEnabled,
         error: error,
         restoreStatus: restoreStatus,
         restoreError: restoreError,
       );

  /// The current lifecycle status.
  final SettingsStatus status;

  /// Whether the toggle should read as on.
  final bool pushEnabled;

  /// The last value known to be both persisted and permitted, used to revert.
  final bool lastKnownGood;

  /// A human-readable error for [SettingsStatus.failure].
  final String? error;

  /// The lifecycle of the "Restore purchases" action.
  final SettingsRestoreStatus restoreStatus;

  /// A human-readable error for [SettingsRestoreStatus.failure].
  final String? restoreError;

  /// Returns a copy with only [restoreStatus]/[restoreError] changed; every
  /// other field is preserved. Used by the bloc to report restore-purchases
  /// progress without disturbing the push-notification lifecycle.
  SettingsState _withRestoreStatus(
    SettingsRestoreStatus restoreStatus, {
    String? restoreError,
  }) {
    return SettingsState._(
      status: status,
      pushEnabled: pushEnabled,
      lastKnownGood: lastKnownGood,
      error: error,
      restoreStatus: restoreStatus,
      restoreError: restoreError,
    );
  }

  @override
  List<Object?> get props => [
    status,
    pushEnabled,
    lastKnownGood,
    error,
    restoreStatus,
    restoreError,
  ];
}
