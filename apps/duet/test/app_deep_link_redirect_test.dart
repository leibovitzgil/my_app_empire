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
import 'dart:io';

import 'package:audio/audio.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/app.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/current_user_name.dart';
import 'package:duet/data/fake_deep_link_service.dart';
import 'package:duet/data/mock_auth_repository.dart';
import 'package:duet/domain/duet_roles.dart';
import 'package:duet/injection.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_roles/user_roles.dart';

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

    final currentUser = CurrentUser(getIt<AuthRepository>().user);
    getIt.registerSingleton<CurrentUser>(currentUser);

    final currentUserName = CurrentUserName(mockAuthRepository.displayName);
    getIt.registerSingleton<CurrentUserName>(currentUserName);

    getIt.registerSingleton<UserRoleRepository>(
      LocalUserRoleRepository(
        storage: getIt<LocalStorageService>(),
        userIdStream: getIt<AuthRepository>().user,
        rolePermissions: DuetRoles.rolePermissions,
        knownRoles: DuetRoles.knownRoles,
      ),
    );

    getIt.registerLazySingleton<PdfRenderService>(PdfxRenderService.new);
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
  }

  testWidgets(
    'a deep-link intent delivered on onIntent navigates go_router to the '
    'matching route',
    (tester) async {
      await registerFakes();
      final fakeDeepLinks = FakeDeepLinkService();
      addTearDown(fakeDeepLinks.dispose);
      getIt.registerLazySingleton<DeepLinkService>(() => fakeDeepLinks);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // No initial link was seeded and the user isn't authenticated, so the
      // root route renders the login screen.
      expect(find.text('Duet'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      // Simulate a deep link (native app_links URI or a push-notification
      // payload routed through `ingest`) recognized by `duetDeepLinkParser`
      // as `/home`.
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
    'a seeded initial link navigates to the matching route on cold start',
    (tester) async {
      await registerFakes();
      final fakeDeepLinks = FakeDeepLinkService()
        ..initialLink = Uri.parse('https://example.com/home');
      addTearDown(fakeDeepLinks.dispose);
      getIt.registerLazySingleton<DeepLinkService>(() => fakeDeepLinks);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );
}
