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

import 'package:analytics/analytics.dart';
import 'package:app_updater/app_updater.dart';
import 'package:audio/audio.dart';
import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/app.dart';
import 'package:duet/data/account_purge.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/current_user_email.dart';
import 'package:duet/data/current_user_name.dart';
import 'package:duet/data/directory_publisher.dart';
import 'package:duet/data/duet_analytics.dart';
import 'package:duet/data/fake_deep_link_service.dart';
import 'package:duet/data/mock_auth_repository.dart';
import 'package:duet/data/perf_tracer.dart';
import 'package:duet/data/recording_path_builder.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:duet/injection.dart';
import 'package:duet/ui/score_page.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monetization/monetization.dart';
import 'package:notifications/notifications.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:remote_config/remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_directory/user_directory.dart';

import 'duet_flow_harness.dart';

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

/// Fails every resolve, fast and without `dart:io` — the piece-deep-link
/// tests below only need the score route's *guard* to pass (the piece
/// exists); actually resolving/rendering the PDF is the reader's own
/// business, covered elsewhere (and real file I/O never completes inside a
/// `testWidgets` body in this sandbox — see `duet_flow_harness.dart`).
class _FailingPdfBinaryCache implements PdfBinaryCache {
  @override
  Future<Result<String>> pathFor(Piece piece) async =>
      ResultFailure<String>(StateError('no binaries in this test'));
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
  ///
  /// [pieceRepository] swaps the default (real, empty `LocalPieceRepository`)
  /// for a pre-seeded fake — the piece-deep-link tests (M5.5) need
  /// `/score/:pieceId`'s guard to find the piece. [pdfBinaryCache] likewise
  /// swaps the real cache for one with no file I/O (see
  /// [_FailingPdfBinaryCache]).
  Future<void> registerFakes({
    PieceRepository? pieceRepository,
    PdfBinaryCache? pdfBinaryCache,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await LocalStorageService.init();
    getIt.registerSingleton<LocalStorageService>(storage);
    // The router's screen-view observer resolves the analytics catalogue
    // (M7.2); a Talker-only AppLogger keeps it headless like injection.dart.
    getIt.registerLazySingleton<DuetAnalytics>(
      () => DuetAnalytics(AppLogger()),
    );
    final mockAuthRepository = MockAuthRepository();
    getIt.registerSingleton<AuthRepository>(mockAuthRepository);
    // HomeScreen's verify-email banner resolves the account seam too —
    // same instance, both contracts, mirroring injection.dart.
    getIt.registerSingleton<AuthAccountProvider>(mockAuthRepository);

    final currentUser = CurrentUser(getIt<AuthRepository>().user);
    getIt.registerSingleton<CurrentUser>(currentUser);

    final currentUserName = CurrentUserName(mockAuthRepository.displayName);
    getIt.registerSingleton<CurrentUserName>(currentUserName);

    // HomeScreen's invite-inbox banner (M5.6) resolves the email seam, the
    // message gateway + invite service, and the monetization service — the
    // in-memory/simulated set, mirroring injection.dart's default branch.
    getIt.registerSingleton<CurrentUserEmail>(
      CurrentUserEmail(
        mockAuthRepository.account.map((account) => account?.email),
      ),
    );
    getIt.registerLazySingleton<MonetizationService>(
      SimulatedMonetizationService.new,
    );
    getIt.registerSingleton<UserMessageGateway>(InMemoryUserMessaging());
    getIt.registerLazySingleton<CollaboratorInviteService>(
      () => DefaultCollaboratorInviteService(
        userDirectory: getIt<UserDirectory>(),
        pieceRepository: getIt<PieceRepository>(),
        monetizationService: getIt<MonetizationService>(),
        messageGateway: getIt<UserMessageGateway>(),
      ),
    );

    getIt.registerLazySingleton<PerfTracer>(NoopPerfTracer.new);
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
    if (pieceRepository != null) {
      getIt.registerSingleton<PieceRepository>(pieceRepository);
    } else {
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
    }
    getIt.registerLazySingleton<AnnotationRepository>(
      () => LocalAnnotationRepository(
        storage: getIt<LocalStorageService>(),
        currentUserId: getIt<CurrentUser>().call,
        pieceRepository: getIt<PieceRepository>(),
      ),
    );
    getIt.registerLazySingleton<PieceBinaryStore>(NoopPieceBinaryStore.new);
    if (pdfBinaryCache != null) {
      getIt.registerSingleton<PdfBinaryCache>(pdfBinaryCache);
    } else {
      getIt.registerLazySingleton<PdfBinaryCache>(
        () => DefaultPdfBinaryCache(
          binaryStore: getIt<PieceBinaryStore>(),
          pdfRenderService: getIt<PdfRenderService>(),
          storage: getIt<LocalStorageService>(),
        ),
      );
    }
    // The score page subscribes to this on mount (M4.1); the local monitor
    // reports always-synced.
    getIt.registerLazySingleton<PieceSyncMonitor>(LocalPieceSyncMonitor.new);

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
    // The force-update gate wraps every routed screen (app.dart); the
    // in-memory remote config's default `min_supported_version: 0.0.0`
    // means it never blocks these navigation tests.
    getIt.registerSingleton<RemoteConfigService>(
      InMemoryRemoteConfigService(),
    );
    getIt.registerLazySingleton<AppUpdateService>(
      () => AppUpdateService(
        remoteConfig: getIt<RemoteConfigService>(),
        // Fixed so the gate never reaches for the `package_info_plus`
        // platform channel (unanswered under the widget-test binding, which
        // would leave `ForceUpdateWidget`'s spinner animating and hang
        // pumpAndSettle). Above the 0.0.0 default → never blocks.
        currentVersion: () async => '1.0.0',
      ),
    );
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

  /// Seeds [pieces] with one piece and returns it.
  Future<Piece> seedPiece(FakePieceRepository pieces) async {
    final result = await pieces.importPiece(
      title: 'Clair de Lune',
      sourcePath: 'clair.pdf',
    );
    return (result as Success<Piece>).value;
  }

  testWidgets(
    'the score and collaborators routes render their pages by piece id',
    (tester) async {
      // Seeded: `/score/:pieceId` now guards the id against the repository
      // (M5.5), so rendering the page requires the piece to exist.
      final pieces = FakePieceRepository();
      final piece = await seedPiece(pieces);
      await registerFakes(
        pieceRepository: pieces,
        pdfBinaryCache: _FailingPdfBinaryCache(),
      );
      final fakeDeepLinks = FakeDeepLinkService();
      addTearDown(fakeDeepLinks.dispose);
      getIt.registerLazySingleton<DeepLinkService>(() => fakeDeepLinks);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      await logIn(tester);

      final context = tester.element(find.byType(HomeScreen));
      final router = GoRouter.of(context);

      unawaited(router.push('/score/${piece.id}'));
      await tester.pumpAndSettle();
      expect(find.byType(DuetScorePage), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      unawaited(router.push('/collaborators/${piece.id}'));
      await tester.pumpAndSettle();
      expect(find.byType(CollaboratorsPage), findsOneWidget);
    },
  );

  // M5.5 — notification tap-through → the exact piece. A push's tap payload
  // (`https://duet.app/piece/<id>`) reaches `DeepLinkService.ingest` via
  // `NotificationTapRouter` (unit-covered in
  // `notification_tap_router_test.dart`); these prove the ingested link
  // actually lands on the right screen through the real `AppView` wiring.

  testWidgets(
    'a piece deep link delivered while signed in opens that exact score',
    (tester) async {
      final pieces = FakePieceRepository();
      final piece = await seedPiece(pieces);
      await registerFakes(
        pieceRepository: pieces,
        pdfBinaryCache: _FailingPdfBinaryCache(),
      );
      final fakeDeepLinks = FakeDeepLinkService();
      addTearDown(fakeDeepLinks.dispose);
      getIt.registerLazySingleton<DeepLinkService>(() => fakeDeepLinks);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      await logIn(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      fakeDeepLinks.ingest(Uri.parse('https://duet.app/piece/${piece.id}'));
      await tester.pumpAndSettle();

      expect(find.byType(DuetScorePage), findsOneWidget);
    },
  );

  testWidgets(
    'a piece deep link arriving while signed out is held until login, '
    'then opens the score',
    (tester) async {
      final pieces = FakePieceRepository();
      final piece = await seedPiece(pieces);
      await registerFakes(
        pieceRepository: pieces,
        pdfBinaryCache: _FailingPdfBinaryCache(),
      );
      final fakeDeepLinks = FakeDeepLinkService();
      addTearDown(fakeDeepLinks.dispose);
      getIt.registerLazySingleton<DeepLinkService>(() => fakeDeepLinks);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      fakeDeepLinks.ingest(Uri.parse('https://duet.app/piece/${piece.id}'));
      await tester.pumpAndSettle();

      // Signed out: held, not navigated.
      expect(find.byType(DuetScorePage), findsNothing);
      expect(find.text('Duet'), findsOneWidget);

      await logIn(tester);

      expect(find.byType(DuetScorePage), findsOneWidget);
    },
  );

  testWidgets(
    'a piece deep link with an unknown id lands on /home with a snackbar',
    (tester) async {
      // Default (empty) repository: any id is unknown.
      await registerFakes();
      final fakeDeepLinks = FakeDeepLinkService();
      addTearDown(fakeDeepLinks.dispose);
      getIt.registerLazySingleton<DeepLinkService>(() => fakeDeepLinks);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      await logIn(tester);

      fakeDeepLinks.ingest(Uri.parse('https://duet.app/piece/no-such-piece'));
      await tester.pumpAndSettle();

      // Bounced home with the G4 snackbar, not stranded on a dead reader.
      expect(find.byType(DuetScorePage), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('That sheet is no longer available'), findsOneWidget);

      // Let the snackbar's auto-dismiss timer elapse so the test ends with
      // no pending timers.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );
}
