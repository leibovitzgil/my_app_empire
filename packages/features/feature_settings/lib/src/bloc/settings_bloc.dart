import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_settings/src/domain/notification_permission_gateway.dart';
import 'package:feature_settings/src/domain/settings_repository.dart';

part 'settings_event.dart';
part 'settings_state.dart';

/// Drives the settings screen: persisted push preference reconciled against the
/// OS notification permission. Never throws across boundaries — every
/// [ResultFailure] is folded into [SettingsStatus.failure].
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({
    required SettingsRepository repository,
    required NotificationPermissionGateway gateway,
  }) : _repository = repository,
       _gateway = gateway,
       super(const SettingsState.loading()) {
    on<SettingsReconcileRequested>(_onReconcile);
    on<SettingsPushToggled>(_onToggled);
    on<SettingsOpenSystemSettingsRequested>(_onOpenSystemSettings);
  }

  final SettingsRepository _repository;
  final NotificationPermissionGateway _gateway;

  Future<void> _onReconcile(
    SettingsReconcileRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final persistedResult = await _repository.readPushEnabled();
    final persisted = persistedResult.valueOrNull;
    if (persisted == null) {
      emit(_fail(persistedResult, fallback: state.lastKnownGood));
      return;
    }

    final statusResult = await _gateway.currentStatus();
    final permission = statusResult.valueOrNull;
    if (permission == null) {
      emit(_fail(statusResult, fallback: persisted));
      return;
    }

    // If the OS permanently denied while we still had the pref on, correct the
    // persisted value so the two never drift apart.
    if (permission == NotificationPermission.permanentlyDenied && persisted) {
      final correction = await _repository.writePushEnabled(false);
      if (correction is ResultFailure<void>) {
        emit(_fail(correction, fallback: false));
        return;
      }
    }

    final effective = persisted && permission == NotificationPermission.granted;
    emit(SettingsState.loaded(pushEnabled: effective));
  }

  Future<void> _onToggled(
    SettingsPushToggled event,
    Emitter<SettingsState> emit,
  ) async {
    if (!event.enabled) {
      final write = await _repository.writePushEnabled(false);
      if (write is ResultFailure<void>) {
        // Keep the toggle on its last known-good value rather than the
        // attempted one, so a failed write never leaves the UI claiming a
        // state that wasn't persisted.
        emit(_fail(write, fallback: state.lastKnownGood));
        return;
      }
      emit(const SettingsState.loaded(pushEnabled: false));
      return;
    }

    emit(const SettingsState.pending(pushEnabled: true));

    final ensured = await _gateway.ensurePermission();
    final permission = ensured.valueOrNull;
    if (permission == null) {
      emit(_fail(ensured, fallback: false));
      return;
    }

    switch (permission) {
      case NotificationPermission.granted:
        final write = await _repository.writePushEnabled(true);
        if (write is ResultFailure<void>) {
          emit(_fail(write, fallback: false));
          return;
        }
        emit(const SettingsState.loaded(pushEnabled: true));
      case NotificationPermission.permanentlyDenied:
        // Keep the persisted pref false; surface the system-settings path.
        emit(const SettingsState.blocked());
      case NotificationPermission.denied:
        emit(
          const SettingsState.failure(
            'Notifications permission was declined.',
            pushEnabled: false,
          ),
        );
    }
  }

  Future<void> _onOpenSystemSettings(
    SettingsOpenSystemSettingsRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final result = await _gateway.openSystemSettings();
    if (result is ResultFailure<void>) {
      emit(_fail(result, fallback: state.pushEnabled));
    }
  }

  SettingsState _fail(Result<Object?> result, {required bool fallback}) {
    final message = result is ResultFailure<Object?>
        ? result.error.toString()
        : 'Something went wrong.';
    return SettingsState.failure(message, pushEnabled: fallback);
  }
}
