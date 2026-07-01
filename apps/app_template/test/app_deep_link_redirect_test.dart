// Exercises app_template's reference redirect-wiring pattern in `app.dart`:
// a deep-link intent fed into `DeepLinkService.onIntent` should actually
// navigate `go_router` via `AppView`'s `redirect`, not just be observable in
// isolation on the fake service (already covered by
// `fake_deep_link_service_test.dart`). This is the seam the factory's
// reference apps are meant to demonstrate end-to-end.
import 'package:app_template/app.dart';
import 'package:app_template/data/fake_deep_link_service.dart';
import 'package:app_template/data/mock_auth_repository.dart';
import 'package:app_template/injection.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() async => getIt.reset());

  testWidgets(
    'a deep-link intent delivered on onIntent navigates go_router to the '
    'matching route',
    (tester) async {
      final fakeDeepLinks = FakeDeepLinkService();
      addTearDown(fakeDeepLinks.dispose);
      getIt
        ..registerLazySingleton<DeepLinkService>(() => fakeDeepLinks)
        ..registerLazySingleton<AuthRepository>(MockAuthRepository.new);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // No initial link was seeded and the user isn't authenticated, so the
      // root route renders the login screen.
      expect(find.text('App Template'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      // Simulate a deep link (native app_links URI or a push-notification
      // payload routed through `ingest`) recognized by
      // `appTemplateDeepLinkParser` as `/home`.
      fakeDeepLinks.ingest(Uri.parse('https://example.com/home'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'an unrecognized deep link does not trigger a redirect',
    (tester) async {
      final fakeDeepLinks = FakeDeepLinkService();
      addTearDown(fakeDeepLinks.dispose);
      getIt
        ..registerLazySingleton<DeepLinkService>(() => fakeDeepLinks)
        ..registerLazySingleton<AuthRepository>(MockAuthRepository.new);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      fakeDeepLinks.ingest(Uri.parse('https://example.com/unknown'));
      await tester.pumpAndSettle();

      // Still on the (unauthenticated) root route; no crash, no navigation.
      expect(find.text('App Template'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    },
  );

  testWidgets(
    'a seeded initial link navigates to the matching route on cold start',
    (tester) async {
      final fakeDeepLinks = FakeDeepLinkService()
        ..initialLink = Uri.parse('https://example.com/home');
      addTearDown(fakeDeepLinks.dispose);
      getIt
        ..registerLazySingleton<DeepLinkService>(() => fakeDeepLinks)
        ..registerLazySingleton<AuthRepository>(MockAuthRepository.new);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );
}
