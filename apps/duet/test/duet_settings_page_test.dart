// Exercises `DuetSettingsPage`'s app-glue on top of `feature_settings`'s
// `SettingsScreen`: the async `NotificationPermissionGateway` load (mirroring
// `DuetScorePage`'s `RecordingPathBuilder` pattern), the M1.5 profile group
// (display-name editing, read-only email, sign-out) sourced from the auth
// account stream, and the "Manage plan" row that pushes the `/paywall` route.
// The get_it registrations below are intentionally standalone statements
// (mirroring `injection.dart`'s own registration block).
// ignore_for_file: cascade_invocations

import 'package:core_utils/core_utils.dart';
import 'package:duet/data/mock_auth_repository.dart';
import 'package:duet/injection.dart';
import 'package:duet/ui/settings_page.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_paywall/feature_paywall.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monetization/monetization.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Grants push permission immediately, avoiding the platform channel a real
/// `NotificationsManager` needs.
class _FakeNotificationPermissionGateway
    implements NotificationPermissionGateway {
  @override
  Future<Result<NotificationPermission>> currentStatus() async =>
      const Success<NotificationPermission>(NotificationPermission.granted);

  @override
  Future<Result<NotificationPermission>> ensurePermission({
    BuildContext? context,
  }) async =>
      const Success<NotificationPermission>(NotificationPermission.granted);

  @override
  Future<Result<void>> openSystemSettings() async => const Success<void>(null);
}

void main() {
  late MockAuthRepository mockAuth;

  tearDown(() async => getIt.reset());

  Future<void> registerFakes() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await LocalStorageService.init();
    getIt.registerSingleton<LocalStorageService>(storage);
    mockAuth = MockAuthRepository();
    getIt.registerSingleton<AuthRepository>(mockAuth);
    getIt.registerSingleton<AuthAccountProvider>(mockAuth);
    getIt.registerLazySingleton<SettingsRepository>(
      () => LocalSettingsRepository(getIt<LocalStorageService>()),
    );
    getIt.registerLazySingletonAsync<NotificationPermissionGateway>(
      () async => _FakeNotificationPermissionGateway(),
    );
    getIt.registerLazySingleton<MonetizationService>(
      SimulatedMonetizationService.new,
    );
  }

  /// Pumps the page inside a mini router mirroring `app.dart`'s `/settings`
  /// and `/paywall` routes ("Manage plan" pushes a route per G8).
  Future<void> pumpSettings(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const DuetSettingsPage(),
        ),
        GoRoute(
          path: '/paywall',
          builder: (context, state) => BlocProvider<PaywallBloc>(
            create: (_) =>
                PaywallBloc(monetizationService: getIt<MonetizationService>())
                  ..add(const PaywallStarted()),
            child: const PaywallScreen(),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump();
  }

  /// Signs the mock account in and lets the account stream reach the page.
  Future<void> signIn(WidgetTester tester) async {
    final login = mockAuth.login('jane.doe@example.com', 'pw');
    await tester.pump(const Duration(seconds: 1));
    await login;
    await tester.pump();
  }

  testWidgets('shows the push-notifications toggle once the async gateway '
      'resolves', (tester) async {
    await registerFakes();
    await pumpSettings(tester);

    expect(find.text('Push notifications'), findsOneWidget);
  });

  testWidgets('shows the Manage plan row, which opens the paywall route', (
    tester,
  ) async {
    await registerFakes();
    await pumpSettings(tester);

    expect(find.text('Manage plan'), findsOneWidget);
    await tester.ensureVisible(find.text('Manage plan'));
    await tester.tap(find.text('Manage plan'));
    // Several fixed-duration pumps rather than `pumpAndSettle` — the paywall
    // route's initial `PaywallStatus.loading` state renders an indeterminate
    // `CircularProgressIndicator`, whose repeating animation never lets the
    // tree go quiet (same reasoning as `duet_flow_harness.dart`'s `settle`).
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(PaywallScreen), findsOneWidget);
  });

  testWidgets('the profile group shows the signed-in name and email', (
    tester,
  ) async {
    await registerFakes();
    await pumpSettings(tester);
    await signIn(tester);

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Jane.doe'), findsOneWidget);
    expect(find.text('jane.doe@example.com'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('editing the display name updates the row via the account '
      'stream', (tester) async {
    await registerFakes();
    await pumpSettings(tester);
    await signIn(tester);

    await tester.ensureVisible(find.text('Jane.doe'));
    await tester.tap(find.text('Jane.doe'));
    await tester.pumpAndSettle();

    expect(find.text('Display name'), findsWidgets);
    await tester.enterText(find.byType(TextField), '  Jane D.  ');
    await tester.tap(find.text('Save'));
    // The mock's updateDisplayName has a 300ms delay before re-emitting.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Jane D.'), findsOneWidget);
    expect(find.text('Name updated.'), findsOneWidget);
  });

  testWidgets('a blank name cannot be saved', (tester) async {
    await registerFakes();
    await pumpSettings(tester);
    await signIn(tester);

    await tester.ensureVisible(find.text('Jane.doe'));
    await tester.tap(find.text('Jane.doe'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    expect(find.text('Name cannot be empty.'), findsOneWidget);
    final save = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('sign out signs the account out', (tester) async {
    await registerFakes();
    await pumpSettings(tester);
    await signIn(tester);

    final signedOut = mockAuth.user.firstWhere((uid) => uid == null);

    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    // The mock's logout has a 500ms delay.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    await signedOut;
  });
}
