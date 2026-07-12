// Exercises app_template's reference redirect-wiring pattern in `app.dart`:
// a deep-link intent fed into `DeepLinkService.onIntent` should actually
// navigate `go_router` via `AppView`'s `redirect`, not just be observable in
// isolation on the fake service (already covered by
// `fake_deep_link_service_test.dart`). This is the seam the factory's
// reference apps are meant to demonstrate end-to-end.
// The get_it registrations below are intentionally standalone statements
// (mirroring `injection.dart`'s own registration block) rather than a single
// cascade, since they're interspersed with `final` locals.
// ignore_for_file: cascade_invocations
import 'dart:async';
import 'dart:io';

import 'package:audio/audio.dart';
import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/app.dart';
import 'package:duet/data/account_purge.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/current_user_name.dart';
import 'package:duet/data/directory_publisher.dart';
import 'package:duet/data/fake_deep_link_service.dart';
import 'package:duet/data/mock_auth_repository.dart';
import 'package:duet/data/recording_path_builder.dart';
import 'package:duet/injection.dart';
import 'package:duet/ui/score_page.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:local_storage/local_storage.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_directory/user_directory.dart';

/// Grants everything without platform channels — mirrors
/// `app_settings_navigation_test.dart`'s fake.
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
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('duet_app_test_');
  });

  tearDown(() async {
    await getIt.reset();
    await tempDir.delete(recursive: true);
  });

  /// Registers the full dependency graph `HomeScreen` (real `feature_library`
  /// content, not a placeholder) needs to build, backed by temp-dir/in-memory
  /// fakes so this stays a plain `flutter test` — no real platform channels.
  Future<void> registerFakes() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await LocalStorageService.init();
    getIt.registerSingleton<LocalStorageService>(storage);
    final mockAuthRepository = MockAuthRepository();
    getIt.registerSingleton<AuthRepository>(mockAuthRepository);
    // HomeScreen's verify-email banner resolves the account seam too —
    // same instance, both contracts, mirroring injection.dart.
    getIt.registerSingleton<AuthAccountProvider>(mockAuthRepository);

    final currentUser = CurrentUser(getIt<AuthRepository>().user);
    getIt.registerSingleton<CurrentUser>(currentUser);

    final currentUserName = CurrentUserName(mockAuthRepository.displayName);
    getIt.registerSingleton<CurrentUserName>(currentUserName);

    getIt.registerLazySingleton<PdfRenderService>(PdfrxRenderService.new);
    getIt.registerLazySingleton<AudioRecorderService>(
      RecordAudioRecorderService.new,
    );
    getIt.registerLazySingleton<AudioPlayerService>(
      JustAudioPlayerService.new,
    );
    getIt.registerLazySingleton<AudioAssetStore>(
      () => LocalAudioAssetStore(documentsDirectory: () async => tempDir),
    );
    getIt.registerLazySingleton<PieceRepository>(
      () => LocalPieceRepository(
        storage: getIt<LocalStorageService>(),
        currentUserId: getIt<CurrentUser>().call,
        pdfRenderService: getIt<PdfRenderService>(),
        annotationRepository: getIt.call<AnnotationRepository>,
        audioAssetStore: getIt<AudioAssetStore>(),
        documentsDirectory: () async => tempDir,
      ),
    );
    getIt.registerLazySingleton<AnnotationRepository>(
      () => LocalAnnotationRepository(
        storage: getIt<LocalStorageService>(),
        currentUserId: getIt<CurrentUser>().call,
        pieceRepository: getIt<PieceRepository>(),
      ),
    );
    getIt.registerLazySingleton<PieceBinaryStore>(NoopPieceBinaryStore.new);

    // The routed destinations resolve these at build time: the score page's
    // recording-path seam, and the settings page's repository + permission
    // gateway.
    getIt.registerLazySingletonAsync<RecordingPathBuilder>(
      () async => RecordingPathBuilder(tempDir),
    );
    getIt.registerLazySingleton<SettingsRepository>(
      () => LocalSettingsRepository(getIt<LocalStorageService>()),
    );
    getIt.registerLazySingleton<UserDirectory>(InMemoryUserDirectory.new);
    getIt.registerLazySingleton<AccountPurge>(MockAccountPurge.new);
    getIt.registerSingleton<DirectoryPublisher>(
      DirectoryPublisher(
        directory: getIt<UserDirectory>(),
        storage: getIt<LocalStorageService>(),
        accounts: mockAuthRepository.account,
      ),
    );
    getIt.registerLazySingletonAsync<NotificationPermissionGateway>(
      () async => _FakeNotificationPermissionGateway(),
    );
  }

  /// Drives the mock repository's 1s-delayed login and settles navigation.
  Future<void> logIn(WidgetTester tester) async {
    final login = getIt<AuthRepository>().login('you@duet.dev', 'pw');
    await tester.pump(const Duration(seconds: 1));
    await login;
    await tester.pumpAndSettle();
  }

  testWidgets(
    'signed-out users land on /login; logging in lands on /home',
    (tester) async {
      await registerFakes();
      final fakeDeepLinks = FakeDeepLinkService();
      addTearDown(fakeDeepLinks.dispose);
      getIt.registerLazySingleton<DeepLinkService>(() => fakeDeepLinks);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // The redirect resolves `/` to the explicit login route.
      expect(find.text('Duet'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      await logIn(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'a deep-link intent arriving while signed out is held until login, '
    'then navigates',
    (tester) async {
      await registerFakes();
      final fakeDeepLinks = FakeDeepLinkService();
      addTearDown(fakeDeepLinks.dispose);
      getIt.registerLazySingleton<DeepLinkService>(() => fakeDeepLinks);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Simulate a deep link (native app_links URI or a push-notification
      // payload routed through `ingest`) recognized by `duetDeepLinkParser`
      // as `/home`. Signed out, it must NOT navigate — login comes first.
      fakeDeepLinks.ingest(Uri.parse('https://example.com/home'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Duet'), findsOneWidget);

      // The held intent wins right after authentication.
      await logIn(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'a deep-link intent delivered while signed in navigates immediately',
    (tester) async {
      await registerFakes();
      final fakeDeepLinks = FakeDeepLinkService();
      addTearDown(fakeDeepLinks.dispose);
      getIt.registerLazySingleton<DeepLinkService>(() => fakeDeepLinks);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      await logIn(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      // Navigate away so the `/home` intent has something to change.
      final context = tester.element(find.byType(HomeScreen));
      unawaited(GoRouter.of(context).push('/settings'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsNothing);

      fakeDeepLinks.ingest(Uri.parse('https://example.com/home'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'an unrecognized deep link does not trigger a redirect',
    (tester) async {
      await registerFakes();
      final fakeDeepLinks = FakeDeepLinkService();
      addTearDown(fakeDeepLinks.dispose);
      getIt.registerLazySingleton<DeepLinkService>(() => fakeDeepLinks);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      fakeDeepLinks.ingest(Uri.parse('https://example.com/unknown'));
      await tester.pumpAndSettle();

      // Still on the (unauthenticated) root route; no crash, no navigation.
      expect(find.text('Duet'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    },
  );

  testWidgets(
    'a seeded initial link survives the cold-start login round-trip',
    (tester) async {
      await registerFakes();
      final fakeDeepLinks = FakeDeepLinkService()
        ..initialLink = Uri.parse('https://example.com/home');
      addTearDown(fakeDeepLinks.dispose);
      getIt.registerLazySingleton<DeepLinkService>(() => fakeDeepLinks);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Cold start with a link but no session: login first.
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Duet'), findsOneWidget);

      await logIn(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'the score and collaborators routes render their pages by piece id',
    (tester) async {
      await registerFakes();
      final fakeDeepLinks = FakeDeepLinkService();
      addTearDown(fakeDeepLinks.dispose);
      getIt.registerLazySingleton<DeepLinkService>(() => fakeDeepLinks);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      await logIn(tester);

      final context = tester.element(find.byType(HomeScreen));
      final router = GoRouter.of(context);

      unawaited(router.push('/score/some-piece-id'));
      await tester.pumpAndSettle();
      expect(find.byType(DuetScorePage), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      unawaited(router.push('/collaborators/some-piece-id'));
      await tester.pumpAndSettle();
      expect(find.byType(CollaboratorsPage), findsOneWidget);
    },
  );
}
