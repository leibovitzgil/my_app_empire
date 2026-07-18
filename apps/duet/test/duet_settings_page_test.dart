// Exercises `DuetSettingsPage`'s app-glue on top of `feature_settings`'s
// `SettingsScreen`: the async `NotificationPermissionGateway` load (mirroring
// `DuetScorePage`'s `RecordingPathBuilder` pattern), the M1.5 profile group
// (display-name editing, read-only email, sign-out) sourced from the auth
// account stream, and the "Manage plan" row that pushes the `/paywall` route.
// The get_it registrations below are intentionally standalone statements
// (mirroring `injection.dart`'s own registration block).
// ignore_for_file: cascade_invocations

import 'package:core_utils/core_utils.dart';
import 'package:duet/data/account_purge.dart';
import 'package:duet/data/directory_publisher.dart';
import 'package:duet/data/mock_auth_repository.dart';
import 'package:duet/injection.dart';
import 'package:duet/legal.dart';
import 'package:duet/ui/settings_page.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_paywall/feature_paywall.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legal_compliance/legal_compliance.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monetization/monetization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_directory/user_directory.dart';

/// A recording [AccountPurge]: pops scripted results in order (succeeding
/// once the script runs dry) and counts calls.
class _FakeAccountPurge implements AccountPurge {
  _FakeAccountPurge([List<Result<void>>? results]) : _results = [...?results];

  final List<Result<void>> _results;
  int calls = 0;

  @override
  Future<Result<void>> deleteAccount() async {
    calls++;
    if (_results.isEmpty) return const Success(null);
    return _results.removeAt(0);
  }
}

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
  late _FakeAccountPurge fakePurge;

  tearDown(() async => getIt.reset());

  Future<void> registerFakes({List<Result<void>>? purgeResults}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await LocalStorageService.init();
    getIt.registerSingleton<LocalStorageService>(storage);
    mockAuth = MockAuthRepository();
    getIt.registerSingleton<AuthRepository>(mockAuth);
    getIt.registerSingleton<AuthAccountProvider>(mockAuth);
    fakePurge = _FakeAccountPurge(purgeResults);
    getIt.registerSingleton<AccountPurge>(fakePurge);
    getIt.registerLazySingleton<SettingsRepository>(
      () => LocalSettingsRepository(getIt<LocalStorageService>()),
    );
    getIt.registerLazySingletonAsync<NotificationPermissionGateway>(
      () async => _FakeNotificationPermissionGateway(),
    );
    getIt.registerLazySingleton<MonetizationService>(
      SimulatedMonetizationService.new,
    );
    getIt.registerLazySingleton<UserDirectory>(InMemoryUserDirectory.new);
    getIt.registerSingleton<DirectoryPublisher>(
      DirectoryPublisher(
        directory: getIt<UserDirectory>(),
        storage: getIt<LocalStorageService>(),
        accounts: mockAuth.account,
      ),
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

  /// Bounded stand-in for `pumpAndSettle` while the danger-zone flow is
  /// active: once deletion starts, the Danger zone row shows an
  /// indeterminate `CircularProgressIndicator` whose animation never lets
  /// the tree go quiet (same reasoning as `duet_flow_harness.dart`).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
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

  testWidgets('the About group shows policy/ToS links and the version', (
    tester,
  ) async {
    await registerFakes();
    await pumpSettings(tester);

    final about = find.text('About');
    await tester.scrollUntilVisible(about, 200);
    expect(about, findsOneWidget);
    expect(find.byType(PrivacyPolicyButton), findsOneWidget);
    expect(find.byType(TermsOfServiceButton), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text(kAppVersion), findsOneWidget);
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

  testWidgets('the Privacy switch persists and applies the discoverable '
      'choice', (tester) async {
    await registerFakes();
    await pumpSettings(tester);
    await signIn(tester);

    final publisher = getIt<DirectoryPublisher>();
    final directory = getIt<UserDirectory>();
    expect(publisher.discoverable, isTrue);
    final visible = await directory.lookupByEmail('jane.doe@example.com');
    expect(visible.valueOrNull, isNotNull);

    final toggle = find.text('Discoverable by email');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    // The mock login already emitted; publishing is synchronous-ish but
    // storage + upsert are async.
    await tester.pump();
    await tester.pump();

    expect(publisher.discoverable, isFalse);
    final hidden = await directory.lookupByEmail('jane.doe@example.com');
    expect(hidden.valueOrNull, isNull);
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

  /// Drives the danger-zone flow up to and including the re-auth dialog's
  /// password confirmation (the mock account is a password account).
  Future<void> confirmDeleteAndReauth(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Delete Account'), 250);
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Account?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    // Tapping Delete starts `_deleteAccount` (spinner up), so bounded pumps.
    await settle(tester);
    expect(find.text("Confirm it's you"), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'pw');
    await tester.tap(find.text('Confirm'));
    // The mock's reauthenticate has a 300ms delay; the purge fake and the
    // spinner row need a few more frames (fixed pumps — the indeterminate
    // progress indicator never lets pumpAndSettle go quiet).
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('deleting the account purges, wipes local storage, and signs '
      'out', (tester) async {
    await registerFakes();
    await pumpSettings(tester);
    await signIn(tester);
    final storage = getIt<LocalStorageService>();
    await storage.setString('pieces.records', 'cached-pieces');
    final signedOut = mockAuth.user.firstWhere((uid) => uid == null);

    await confirmDeleteAndReauth(tester);
    // The mock's logout has a 500ms delay.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(fakePurge.calls, 1);
    expect(storage.getString('pieces.records'), isNull);
    await signedOut;
  });

  testWidgets('a stale-sign-in rejection re-runs re-auth and retries the '
      'purge', (tester) async {
    await registerFakes(
      purgeResults: [
        const ResultFailure<void>(AuthFailure.requiresRecentLogin()),
        const Success<void>(null),
      ],
    );
    await pumpSettings(tester);
    await signIn(tester);
    final signedOut = mockAuth.user.firstWhere((uid) => uid == null);

    await confirmDeleteAndReauth(tester);

    // The stale rejection re-opened the re-auth dialog: confirm once more.
    expect(find.text("Confirm it's you"), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'pw');
    await tester.tap(find.text('Confirm'));
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(fakePurge.calls, 2);
    await signedOut;
  });

  testWidgets('a network failure shows a retry snackbar and leaves the '
      'session fully intact', (tester) async {
    await registerFakes(
      purgeResults: [const ResultFailure<void>(AuthFailure.network())],
    );
    await pumpSettings(tester);
    await signIn(tester);
    final storage = getIt<LocalStorageService>();
    await storage.setString('pieces.records', 'cached-pieces');
    var sawSignOut = false;
    final subscription = mockAuth.user.listen((uid) {
      if (uid == null) sawSignOut = true;
    });
    addTearDown(subscription.cancel);

    await confirmDeleteAndReauth(tester);

    expect(fakePurge.calls, 1);
    expect(
      find.text('No connection. Check your network and retry.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(storage.getString('pieces.records'), 'cached-pieces');
    expect(sawSignOut, isFalse);
  });

  testWidgets('cancelling the confirmation dialog never purges', (
    tester,
  ) async {
    await registerFakes();
    await pumpSettings(tester);
    await signIn(tester);

    await tester.scrollUntilVisible(find.text('Delete Account'), 250);
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fakePurge.calls, 0);
    expect(find.text("Confirm it's you"), findsNothing);
  });

  testWidgets('backing out of re-auth aborts the deletion', (tester) async {
    await registerFakes();
    await pumpSettings(tester);
    await signIn(tester);
    var sawSignOut = false;
    final subscription = mockAuth.user.listen((uid) {
      if (uid == null) sawSignOut = true;
    });
    addTearDown(subscription.cancel);

    await tester.scrollUntilVisible(find.text('Delete Account'), 250);
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    // Deletion is now underway (spinner up), so bounded pumps until the
    // re-auth dialog is on screen.
    await settle(tester);
    expect(find.text("Confirm it's you"), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(fakePurge.calls, 0);
    expect(sawSignOut, isFalse);
  });
}
