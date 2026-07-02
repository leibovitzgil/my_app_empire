part of 'settings_bloc.dart';

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Re-reads persisted prefs and current permission. Dispatched on mount and on
/// app resume so the toggle always reflects the OS truth.
final class SettingsReconcileRequested extends SettingsEvent {
  const SettingsReconcileRequested();
}

/// The user flipped the push toggle to [enabled].
final class SettingsPushToggled extends SettingsEvent {
  const SettingsPushToggled({required this.enabled});

  /// The requested new value.
  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

/// The user asked to open the OS notification settings.
final class SettingsOpenSystemSettingsRequested extends SettingsEvent {
  const SettingsOpenSystemSettingsRequested();
}

/// The user asked to restore previous purchases.
final class SettingsRestorePurchasesRequested extends SettingsEvent {
  const SettingsRestorePurchasesRequested();
}
