import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockNotificationPermissionGateway extends Mock
    implements NotificationPermissionGateway {}

class MockMonetizationService extends Mock implements MonetizationService {}

class MockCustomerInfo extends Mock implements CustomerInfo {}

void main() {
  group('SettingsBloc', () {
    late SettingsRepository repository;
    late NotificationPermissionGateway gateway;
    late MonetizationService monetization;

    setUp(() {
      repository = MockSettingsRepository();
      gateway = MockNotificationPermissionGateway();
      monetization = MockMonetizationService();
    });

    SettingsBloc build() => SettingsBloc(
      repository: repository,
      gateway: gateway,
      monetizationService: monetization,
    );

    test('initial state is loading', () {
      expect(build().state, const SettingsState.loading());
    });

    group('reconcile', () {
      blocTest<SettingsBloc, SettingsState>(
        'persisted-on + granted => loaded(on)',
        build: () {
          when(
            repository.readPushEnabled,
          ).thenAnswer((_) async => const Success<bool>(true));
          when(gateway.currentStatus).thenAnswer(
            (_) async => const Success<NotificationPermission>(
              NotificationPermission.granted,
            ),
          );
          return build();
        },
        act: (bloc) => bloc.add(const SettingsReconcileRequested()),
        expect: () => const [SettingsState.loaded(pushEnabled: true)],
      );

      // AC1: fresh install defaults to off; never prompts on mount.
      blocTest<SettingsBloc, SettingsState>(
        'fresh install: persisted-off + granted => loaded(off)',
        build: () {
          when(
            repository.readPushEnabled,
          ).thenAnswer((_) async => const Success<bool>(false));
          when(gateway.currentStatus).thenAnswer(
            (_) async => const Success<NotificationPermission>(
              NotificationPermission.granted,
            ),
          );
          return build();
        },
        act: (bloc) => bloc.add(const SettingsReconcileRequested()),
        expect: () => const [SettingsState.loaded(pushEnabled: false)],
        verify: (_) {
          // Reconcile must never trigger the prompting flow.
          verifyNever(gateway.ensurePermission);
        },
      );

      // AC7: persisted-on but OS only denied (re-promptable, not permanent) =>
      // effective off, and the pref is left intact (no destructive correction).
      blocTest<SettingsBloc, SettingsState>(
        'persisted-on + denied => loaded(off) without rewriting the pref',
        build: () {
          when(
            repository.readPushEnabled,
          ).thenAnswer((_) async => const Success<bool>(true));
          when(gateway.currentStatus).thenAnswer(
            (_) async => const Success<NotificationPermission>(
              NotificationPermission.denied,
            ),
          );
          return build();
        },
        act: (bloc) => bloc.add(const SettingsReconcileRequested()),
        expect: () => const [SettingsState.loaded(pushEnabled: false)],
        verify: (_) {
          verifyNever(() => repository.writePushEnabled(any<bool>()));
        },
      );

      // Unhappy path: persisted read fails => failure, no permission read.
      blocTest<SettingsBloc, SettingsState>(
        'readPushEnabled failure => failure(off)',
        build: () {
          when(
            repository.readPushEnabled,
          ).thenAnswer((_) async => ResultFailure<bool>(Exception('disk')));
          return build();
        },
        act: (bloc) => bloc.add(const SettingsReconcileRequested()),
        expect: () => [
          isA<SettingsState>()
              .having((s) => s.status, 'status', SettingsStatus.failure)
              .having((s) => s.pushEnabled, 'pushEnabled', false),
        ],
        verify: (_) {
          verifyNever(gateway.currentStatus);
        },
      );

      // Unhappy path: permission read fails => failure, fallback to persisted.
      blocTest<SettingsBloc, SettingsState>(
        'currentStatus failure => failure(fallback persisted)',
        build: () {
          when(
            repository.readPushEnabled,
          ).thenAnswer((_) async => const Success<bool>(true));
          when(gateway.currentStatus).thenAnswer(
            (_) async => ResultFailure<NotificationPermission>(
              Exception('os'),
            ),
          );
          return build();
        },
        act: (bloc) => bloc.add(const SettingsReconcileRequested()),
        expect: () => [
          isA<SettingsState>()
              .having((s) => s.status, 'status', SettingsStatus.failure)
              .having((s) => s.pushEnabled, 'pushEnabled', true),
        ],
      );

      // AC6/AC7 unhappy: drift correction itself fails to persist => failure,
      // and the toggle is forced off so it never falsely reads on.
      blocTest<SettingsBloc, SettingsState>(
        'permanentlyDenied correction write fails => failure(off)',
        build: () {
          when(
            repository.readPushEnabled,
          ).thenAnswer((_) async => const Success<bool>(true));
          when(gateway.currentStatus).thenAnswer(
            (_) async => const Success<NotificationPermission>(
              NotificationPermission.permanentlyDenied,
            ),
          );
          when(
            () => repository.writePushEnabled(false),
          ).thenAnswer((_) async => ResultFailure<void>(Exception('disk')));
          return build();
        },
        act: (bloc) => bloc.add(const SettingsReconcileRequested()),
        expect: () => [
          isA<SettingsState>()
              .having((s) => s.status, 'status', SettingsStatus.failure)
              .having((s) => s.pushEnabled, 'pushEnabled', false),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'persisted-on + permanentlyDenied => persist-corrected loaded(off)',
        build: () {
          when(
            repository.readPushEnabled,
          ).thenAnswer((_) async => const Success<bool>(true));
          when(gateway.currentStatus).thenAnswer(
            (_) async => const Success<NotificationPermission>(
              NotificationPermission.permanentlyDenied,
            ),
          );
          when(
            () => repository.writePushEnabled(false),
          ).thenAnswer((_) async => const Success<void>(null));
          return build();
        },
        act: (bloc) => bloc.add(const SettingsReconcileRequested()),
        expect: () => const [SettingsState.loaded(pushEnabled: false)],
        verify: (_) {
          verify(() => repository.writePushEnabled(false)).called(1);
        },
      );
    });

    group('toggle on', () {
      blocTest<SettingsBloc, SettingsState>(
        'granted => pending then loaded(on) and persists true',
        build: () {
          when(gateway.ensurePermission).thenAnswer(
            (_) async => const Success<NotificationPermission>(
              NotificationPermission.granted,
            ),
          );
          when(
            () => repository.writePushEnabled(true),
          ).thenAnswer((_) async => const Success<void>(null));
          return build();
        },
        act: (bloc) => bloc.add(const SettingsPushToggled(enabled: true)),
        expect: () => const [
          SettingsState.pending(pushEnabled: true),
          SettingsState.loaded(pushEnabled: true),
        ],
        verify: (_) {
          verify(() => repository.writePushEnabled(true)).called(1);
        },
      );

      blocTest<SettingsBloc, SettingsState>(
        'permanentlyDenied => pending then blocked; never persists true',
        build: () {
          when(gateway.ensurePermission).thenAnswer(
            (_) async => const Success<NotificationPermission>(
              NotificationPermission.permanentlyDenied,
            ),
          );
          return build();
        },
        act: (bloc) => bloc.add(const SettingsPushToggled(enabled: true)),
        expect: () => const [
          SettingsState.pending(pushEnabled: true),
          SettingsState.blocked(),
        ],
        verify: (_) {
          verifyNever(() => repository.writePushEnabled(true));
        },
      );

      blocTest<SettingsBloc, SettingsState>(
        'denied => pending then revert + failure(off)',
        build: () {
          when(gateway.ensurePermission).thenAnswer(
            (_) async => const Success<NotificationPermission>(
              NotificationPermission.denied,
            ),
          );
          return build();
        },
        act: (bloc) => bloc.add(const SettingsPushToggled(enabled: true)),
        expect: () => [
          const SettingsState.pending(pushEnabled: true),
          isA<SettingsState>()
              .having((s) => s.status, 'status', SettingsStatus.failure)
              .having((s) => s.pushEnabled, 'pushEnabled', false),
        ],
        verify: (_) {
          verifyNever(() => repository.writePushEnabled(true));
        },
      );

      // Unhappy path: the permission flow itself errors => pending then
      // failure(off); the pref is never written on.
      blocTest<SettingsBloc, SettingsState>(
        'ensurePermission failure => pending then failure(off)',
        build: () {
          when(gateway.ensurePermission).thenAnswer(
            (_) async => ResultFailure<NotificationPermission>(
              Exception('plugin'),
            ),
          );
          return build();
        },
        act: (bloc) => bloc.add(const SettingsPushToggled(enabled: true)),
        expect: () => [
          const SettingsState.pending(pushEnabled: true),
          isA<SettingsState>()
              .having((s) => s.status, 'status', SettingsStatus.failure)
              .having((s) => s.pushEnabled, 'pushEnabled', false),
        ],
        verify: (_) {
          verifyNever(() => repository.writePushEnabled(true));
        },
      );

      // Unhappy path: permission granted but persistence fails => failure(off)
      // so the UI does not falsely show on after a failed write.
      blocTest<SettingsBloc, SettingsState>(
        'granted but writePushEnabled(true) fails => pending then failure(off)',
        build: () {
          when(gateway.ensurePermission).thenAnswer(
            (_) async => const Success<NotificationPermission>(
              NotificationPermission.granted,
            ),
          );
          when(
            () => repository.writePushEnabled(true),
          ).thenAnswer((_) async => ResultFailure<void>(Exception('disk')));
          return build();
        },
        act: (bloc) => bloc.add(const SettingsPushToggled(enabled: true)),
        expect: () => [
          const SettingsState.pending(pushEnabled: true),
          isA<SettingsState>()
              .having((s) => s.status, 'status', SettingsStatus.failure)
              .having((s) => s.pushEnabled, 'pushEnabled', false),
        ],
      );
    });

    blocTest<SettingsBloc, SettingsState>(
      'toggle off persists false and emits loaded(off)',
      build: () {
        when(
          () => repository.writePushEnabled(false),
        ).thenAnswer((_) async => const Success<void>(null));
        return build();
      },
      act: (bloc) => bloc.add(const SettingsPushToggled(enabled: false)),
      expect: () => const [SettingsState.loaded(pushEnabled: false)],
      verify: (_) {
        verify(() => repository.writePushEnabled(false)).called(1);
      },
    );

    // Unhappy path: toggling off but persistence fails => failure (keeps the
    // last-known-good fallback rather than silently dropping the change).
    blocTest<SettingsBloc, SettingsState>(
      'toggle off but writePushEnabled(false) fails => failure',
      build: () {
        when(
          () => repository.writePushEnabled(false),
        ).thenAnswer((_) async => ResultFailure<void>(Exception('disk')));
        return build();
      },
      act: (bloc) => bloc.add(const SettingsPushToggled(enabled: false)),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.status,
          'status',
          SettingsStatus.failure,
        ),
      ],
    );

    blocTest<SettingsBloc, SettingsState>(
      'open settings invokes gateway.openSystemSettings',
      build: () {
        when(
          gateway.openSystemSettings,
        ).thenAnswer((_) async => const Success<void>(null));
        return build();
      },
      act: (bloc) => bloc.add(const SettingsOpenSystemSettingsRequested()),
      expect: () => const <SettingsState>[],
      verify: (_) {
        verify(gateway.openSystemSettings).called(1);
      },
    );

    // Unhappy path: opening system settings fails => surface a failure state.
    blocTest<SettingsBloc, SettingsState>(
      'open settings failure => failure',
      build: () {
        when(
          gateway.openSystemSettings,
        ).thenAnswer((_) async => ResultFailure<void>(Exception('no app')));
        return build();
      },
      act: (bloc) => bloc.add(const SettingsOpenSystemSettingsRequested()),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.status,
          'status',
          SettingsStatus.failure,
        ),
      ],
      verify: (_) {
        verify(gateway.openSystemSettings).called(1);
      },
    );

    group('restore purchases', () {
      blocTest<SettingsBloc, SettingsState>(
        'emits [restoring, success] when a purchase is restored',
        build: () {
          when(
            monetization.restorePurchases,
          ).thenAnswer((_) async => MockCustomerInfo());
          return build();
        },
        act: (bloc) => bloc.add(const SettingsRestorePurchasesRequested()),
        expect: () => [
          isA<SettingsState>().having(
            (s) => s.restoreStatus,
            'restoreStatus',
            SettingsRestoreStatus.restoring,
          ),
          isA<SettingsState>().having(
            (s) => s.restoreStatus,
            'restoreStatus',
            SettingsRestoreStatus.success,
          ),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'emits [restoring, failure] when there is nothing to restore',
        build: () {
          when(
            monetization.restorePurchases,
          ).thenAnswer((_) async => null);
          return build();
        },
        act: (bloc) => bloc.add(const SettingsRestorePurchasesRequested()),
        expect: () => [
          isA<SettingsState>().having(
            (s) => s.restoreStatus,
            'restoreStatus',
            SettingsRestoreStatus.restoring,
          ),
          isA<SettingsState>()
              .having(
                (s) => s.restoreStatus,
                'restoreStatus',
                SettingsRestoreStatus.failure,
              )
              .having(
                (s) => s.restoreError,
                'restoreError',
                'Nothing to restore.',
              ),
        ],
      );
    });
  });
}
