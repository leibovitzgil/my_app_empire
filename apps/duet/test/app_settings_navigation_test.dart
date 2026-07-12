// Exercises the actual `/settings` `go_router` route wiring `app.dart`
// registers: tapping the Settings icon on the real `HomeScreen` (which hosts
// `feature_library`'s `LibraryPage`) must navigate to the real
// `DuetSettingsPage` — not just that `LibraryHomeScreen`'s `onOpenSettings`
// callback fires in isolation (already covered by `feature_library`'s own
// `library_screen_test.dart`) or that `DuetSettingsPage` renders correctly
// once mounted directly (already covered by `duet_settings_page_test.dart`).
// Uses a small `GoRouter` mirroring `app.dart`'s `/home`/`/settings` routes
// rather than the full `App` widget, so this doesn't need real authentication
// — see `app_deep_link_redirect_test.dart` for the app-level deep-link seam,
// which is a different concern.
import 'package:core_utils/core_utils.dart';
import 'package:duet/app.dart';
import 'package:duet/data/account_purge.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/current_user_name.dart';
import 'package:duet/data/directory_publisher.dart';
import 'package:duet/data/mock_auth_repository.dart';
import 'package:duet/domain/domain.dart';
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
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_directory/user_directory.dart';

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

/// An empty [PieceRepository] — this test never imports/inspects a sheet.
class _EmptyPieceRepository implements PieceRepository {
  @override
  Stream<List<Piece>> watchPieces() => Stream.value(const []);

  @override
  Future<Result<Piece>> getPiece(String pieceId) => throw UnimplementedError();

  @override
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
    String? ownerName,
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
  Future<Result<void>> addCollaborator(
    String pieceId, {
    required String userId,
    String? name,
    String? email,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> removeCollaborator(String pieceId, String userId) =>
      throw UnimplementedError();

  @override
  Future<Result<Piece>> pairCollaborator(
    String pieceId, {
    required String collaboratorId,
    String? collaboratorName,
    String? collaboratorEmail,
    String? ownerName,
  }) => throw UnimplementedError();

  @override
  Future<Result<Piece>> registerImportedPiece({
    required String pieceId,
    required String title,
    required String ownerId,
    required String sourcePath,
    String? collaboratorId,
    String? ownerName,
    String? collaboratorName,
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

  Future<void> pumpHome(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await LocalStorageService.init();
    // HomeScreen's verify-email banner resolves both auth contracts —
    // one mock instance serves both, mirroring injection.dart.
    final mockAuthRepository = MockAuthRepository();
    getIt
      ..registerSingleton<LocalStorageService>(storage)
      ..registerSingleton<AuthRepository>(mockAuthRepository)
      ..registerSingleton<AuthAccountProvider>(mockAuthRepository)
      ..registerSingleton<CurrentUser>(CurrentUser(Stream.value('user-1')))
      ..registerSingleton<CurrentUserName>(CurrentUserName(Stream.value(null)))
      ..registerSingleton<PieceRepository>(_EmptyPieceRepository())
      ..registerLazySingleton<PieceBinaryStore>(NoopPieceBinaryStore.new)
      ..registerLazySingleton<PdfBinaryCache>(
        () => DefaultPdfBinaryCache(
          binaryStore: getIt<PieceBinaryStore>(),
          pdfRenderService: getIt<PdfRenderService>(),
          storage: getIt<LocalStorageService>(),
        ),
      )
      ..registerSingleton<PdfRenderService>(_UnusedPdfRenderService())
      ..registerLazySingleton<MonetizationService>(
        SimulatedMonetizationService.new,
      )
      ..registerLazySingleton<UserDirectory>(InMemoryUserDirectory.new)
      ..registerLazySingleton<AccountPurge>(MockAccountPurge.new)
      ..registerSingleton<DirectoryPublisher>(
        DirectoryPublisher(
          directory: getIt<UserDirectory>(),
          storage: getIt<LocalStorageService>(),
          accounts: mockAuthRepository.account,
        ),
      )
      ..registerLazySingleton<SettingsRepository>(
        () => LocalSettingsRepository(getIt<LocalStorageService>()),
      )
      ..registerLazySingletonAsync<NotificationPermissionGateway>(
        () async => _FakeNotificationPermissionGateway(),
      );

    // Mirrors `app.dart`'s `/home`/`/settings`/`/paywall` `GoRoute`s exactly,
    // minus the auth redirect wrapper `AppView` layers on top (that seam is
    // `app_deep_link_redirect_test.dart`'s concern) — this router proves the
    // same routes/builders app.dart registers.
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
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
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets(
    'reaches /settings from Home via the Settings icon and sees Manage plan',
    (tester) async {
      await pumpHome(tester);

      expect(find.byTooltip('Settings'), findsOneWidget);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.byType(DuetSettingsPage), findsOneWidget);
      expect(find.text('Manage plan'), findsOneWidget);
    },
  );
}
