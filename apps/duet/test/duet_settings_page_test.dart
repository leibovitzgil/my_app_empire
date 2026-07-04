// Exercises `DuetSettingsPage`'s app-glue on top of `feature_settings`'s
// `SettingsScreen`: the async `NotificationPermissionGateway` load (mirroring
// `DuetScorePage`'s `RecordingPathBuilder` pattern) and the Teacher-only
// "Manage plan" row, gated by `PermissionGate` (not `RoleGate` — see
// `DuetSettingsPage`'s doc for why: Teacher/Student share a rank).
// The get_it registrations below are intentionally standalone statements
// (mirroring `injection.dart`'s own registration block).
// ignore_for_file: cascade_invocations
import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:duet/injection.dart';
import 'package:duet/ui/settings_page.dart';
import 'package:feature_library/feature_library.dart' show DuetPermissions;
import 'package:feature_paywall/feature_paywall.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monetization/monetization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_roles/user_roles.dart';

/// A minimal [UserRoleRepository] fake whose permission grant is fixed at
/// construction, mirroring `library_screen_test.dart`'s
/// `_AllowAllUserRoleRepository` convention.
class _FakeUserRoleRepository implements UserRoleRepository {
  _FakeUserRoleRepository({required this.isTeacher});

  final bool isTeacher;
  final _controller = StreamController<AppRole>.broadcast();

  @override
  Stream<AppRole> get currentRole => _controller.stream;

  @override
  Future<Result<AppRole>> getRole() async => const Success(AppRole.member);

  @override
  bool hasPermission(Permission permission) =>
      isTeacher && permission == DuetPermissions.importPiece;

  @override
  bool hasMinimumRole(AppRole role) => true;

  @override
  Future<Result<void>> assignRole(String userId, AppRole role) async =>
      const Success<void>(null);
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
  tearDown(() async => getIt.reset());

  Future<void> registerFakes({required bool isTeacher}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await LocalStorageService.init();
    getIt.registerSingleton<LocalStorageService>(storage);
    getIt.registerSingleton<UserRoleRepository>(
      _FakeUserRoleRepository(isTeacher: isTeacher),
    );
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

  testWidgets('shows the push-notifications toggle once the async gateway '
      'resolves', (tester) async {
    await registerFakes(isTeacher: false);

    await tester.pumpWidget(
      const MaterialApp(home: DuetSettingsPage()),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Push notifications'), findsOneWidget);
  });

  testWidgets('a teacher sees the Manage plan row, which opens the paywall', (
    tester,
  ) async {
    await registerFakes(isTeacher: true);

    await tester.pumpWidget(
      const MaterialApp(home: DuetSettingsPage()),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Manage plan'), findsOneWidget);

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

  testWidgets('a student does not see the Manage plan row', (tester) async {
    await registerFakes(isTeacher: false);

    await tester.pumpWidget(
      const MaterialApp(home: DuetSettingsPage()),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Manage plan'), findsNothing);
  });
}
