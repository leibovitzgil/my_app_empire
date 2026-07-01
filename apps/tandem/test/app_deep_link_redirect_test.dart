// Exercises Tandem's deep-link wiring in `app.dart`: a recognized deep link
// (an initial link on cold start, or one ingested mid-session) should skip
// the onboarding carousel entirely, exactly like a returning user, and land
// directly on the login screen (or straight through to the live list, if
// already authenticated). This is the seam the factory's reference apps are
// meant to demonstrate end-to-end — mirrors
// apps/app_template/test/app_deep_link_redirect_test.dart.
import 'package:deep_linking/deep_linking.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tandem/app.dart';
import 'package:tandem/data/mock_auth_repository.dart';
import 'package:tandem/injection.dart';

import 'fake_deep_link_service.dart';

void main() {
  tearDown(() async => getIt.reset());

  /// Registers the same fakes `tandem_app_test.dart` registers, plus
  /// [fakeDeepLinks] as the [DeepLinkService].
  Future<void> registerFakes(FakeDeepLinkService fakeDeepLinks) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await LocalStorageService.init();
    final grocery = InMemoryGroceryRepository(
      demo: false,
      clock: () => DateTime(2026, 6, 28, 12),
    );
    addTearDown(grocery.dispose);

    getIt
      ..registerSingleton<LocalStorageService>(storage)
      ..registerLazySingleton<AuthRepository>(MockAuthRepository.new)
      ..registerSingleton<GroceryRepository>(grocery)
      ..registerSingleton<PresenceRepository>(grocery)
      ..registerSingleton<MembershipRepository>(grocery)
      ..registerLazySingleton<DeepLinkService>(() => fakeDeepLinks);
  }

  testWidgets(
    'a seeded initial deep link skips onboarding on cold start and lands '
    'directly on the login screen',
    (tester) async {
      final fakeDeepLinks = FakeDeepLinkService()
        ..initialLink = Uri.parse('https://tandem.app/join/household');
      addTearDown(fakeDeepLinks.dispose);
      await registerFakes(fakeDeepLinks);

      await tester.pumpWidget(const TandemApp());
      await tester.pumpAndSettle();

      // Onboarding never appears...
      expect(find.text('Shop together, live'), findsNothing);
      // ...instead the login screen renders directly.
      expect(find.text('Continue with Google'), findsOneWidget);
    },
  );

  testWidgets(
    'a deep link ingested mid-session skips onboarding even though it '
    'would normally still be showing',
    (tester) async {
      final fakeDeepLinks = FakeDeepLinkService();
      addTearDown(fakeDeepLinks.dispose);
      await registerFakes(fakeDeepLinks);

      await tester.pumpWidget(const TandemApp());
      await tester.pumpAndSettle();

      // No initial link was seeded, so onboarding shows as normal.
      expect(find.text('Shop together, live'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);

      // A deep link arrives while the user is still looking at onboarding
      // (e.g. they tapped a household invite link from another app).
      fakeDeepLinks.ingest(Uri.parse('https://tandem.app/join/household'));
      await tester.pumpAndSettle();

      // Onboarding is skipped; the login screen appears directly.
      expect(find.text('Shop together, live'), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
    },
  );
}
