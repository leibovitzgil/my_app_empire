// Exercises the actual `/settings` `go_router` route wiring `app.dart`
// registers: tapping the Settings icon on the real `HomeScreen` (which hosts
// `feature_library`'s `LibraryPage`) must navigate to the real
// `DuetSettingsPage`, for both the Teacher and the Student role — not just
// that `LibraryHomeScreen`'s `onOpenSettings` callback fires in isolation
// (already covered by `feature_library`'s own `library_screen_test.dart`) or
// that `DuetSettingsPage` renders correctly once mounted directly (already
// covered by `duet_settings_page_test.dart`). Uses a small `GoRouter`
// mirroring `app.dart`'s `/home`/`/settings` routes rather than the full
// `App` widget, so this doesn't need real authentication/role-selection —
// see `app_deep_link_redirect_test.dart` for the app-level deep-link seam,
// which is a different concern.
import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:duet/app.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/current_user_name.dart';
import 'package:duet/domain/duet_roles.dart';
import 'package:duet/injection.dart';
import 'package:duet/ui/settings_page.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:local_storage/local_storage.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_roles/user_roles.dart';

/// A minimal, permission-mapped [UserRoleRepository], mirroring
/// `duet_settings_page_test.dart`'s `_FakeUserRoleRepository`: grants exactly
/// the teacher-only tokens `DuetRoles.rolePermissions` maps, so this test
/// proves gating through the same permission surface the real app uses
/// rather than a shortcut "allow everything" fake.
class _FakeUserRoleRepository implements UserRoleRepository {
  _FakeUserRoleRepository({required this.isTeacher});

  final bool isTeacher;
  final _controller = StreamController<AppRole>.broadcast();

  @override
  Stream<AppRole> get currentRole => _controller.stream;

  @override
  Future<Result<AppRole>> getRole() async =>
      Success(isTeacher ? DuetRoles.teacher : DuetRoles.student);

  @override
  bool hasPermission(Permission permission) =>
      (isTeacher ? DuetRoles.rolePermissions['teacher']! : const <Permission>{})
          .contains(permission);

  @override
  bool hasMinimumRole(AppRole role) => true;

  @override
  Future<Result<void>> assignRole(String userId, AppRole role) async =>
      const Success<void>(null);
}

/// Never touches the PDF import flow — this test never opens it.
class _UnusedPdfRenderService implements PdfRenderService {
  @override
  Future<Result<int>> open(String path) => throw UnimplementedError();

  @override
  Future<Result<PdfPageImage>> renderPage(int pageIndex, {double scale = 1}) =>
      throw UnimplementedError();

  @override
  Future<Result<String>> checksum(String path) => throw UnimplementedError();
}

/// An empty [PieceRepository] — this test never imports/inspects a piece.
class _EmptyPieceRepository implements PieceRepository {
  @override
  Stream<List<Piece>> watchPieces() => Stream.value(const []);

  @override
  Future<Result<Piece>> getPiece(String pieceId) => throw UnimplementedError();

  @override
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
    String? teacherName,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> renamePiece(String pieceId, String title) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> deletePiece(String pieceId) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> leavePiece(String pieceId) => throw UnimplementedError();

  @override
  Future<Result<Piece>> pairStudent(
    String pieceId, {
    required String studentId,
    String? studentName,
    String? teacherName,
  }) => throw UnimplementedError();

  @override
  Future<Result<Piece>> registerImportedPiece({
    required String pieceId,
    required String title,
    required String teacherId,
    required String sourcePath,
    String? studentId,
    String? teacherName,
    String? studentName,
  }) => throw UnimplementedError();
}

/// Grants push permission immediately, avoiding the platform channel a real
/// `NotificationsManager` needs — mirrors `duet_settings_page_test.dart`'s
/// `_FakeNotificationPermissionGateway`.
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

  Future<void> pumpHomeAt(
    WidgetTester tester, {
    required bool isTeacher,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await LocalStorageService.init();
    getIt
      ..registerSingleton<LocalStorageService>(storage)
      ..registerSingleton<CurrentUser>(
        CurrentUser(Stream.value(isTeacher ? 'teacher-1' : 'student-1')),
      )
      ..registerSingleton<CurrentUserName>(CurrentUserName(Stream.value(null)))
      ..registerSingleton<UserRoleRepository>(
        _FakeUserRoleRepository(isTeacher: isTeacher),
      )
      ..registerSingleton<PieceRepository>(_EmptyPieceRepository())
      ..registerSingleton<PdfRenderService>(_UnusedPdfRenderService())
      ..registerLazySingleton<SettingsRepository>(
        () => LocalSettingsRepository(getIt<LocalStorageService>()),
      )
      ..registerLazySingletonAsync<NotificationPermissionGateway>(
        () async => _FakeNotificationPermissionGateway(),
      );

    // Mirrors `app.dart`'s `/home`/`/settings` `GoRoute`s exactly, minus the
    // auth/role-selection redirect wrapper `AppView` layers on top (that
    // seam is `app_deep_link_redirect_test.dart`'s concern) — this router
    // proves the same two routes/builders app.dart registers.
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const DuetSettingsPage(),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets(
    'a teacher can reach /settings from Home via the Settings icon',
    (tester) async {
      await pumpHomeAt(tester, isTeacher: true);

      expect(find.byTooltip('Settings'), findsOneWidget);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.byType(DuetSettingsPage), findsOneWidget);
      expect(find.text('Manage plan'), findsOneWidget);
    },
  );

  testWidgets(
    'a student can reach /settings from Home via the Settings icon, but '
    "doesn't see the teacher-only Manage plan row",
    (tester) async {
      await pumpHomeAt(tester, isTeacher: false);

      expect(find.byTooltip('Settings'), findsOneWidget);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.byType(DuetSettingsPage), findsOneWidget);
      expect(find.text('Manage plan'), findsNothing);
    },
  );
}
