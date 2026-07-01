import 'package:feature_auth/feature_auth.dart';
import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tandem/app.dart';
import 'package:tandem/data/mock_auth_repository.dart';
import 'package:tandem/injection.dart';

void main() {
  tearDown(() async => getIt.reset());

  testWidgets('onboarding -> login -> live shared list', (tester) async {
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
      ..registerSingleton<MembershipRepository>(grocery);

    await tester.pumpWidget(const TandemApp());
    await tester.pumpAndSettle();

    // 1. Onboarding (Tandem copy).
    expect(find.text('Shop together, live'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // 2. Login (shared SignInView with Tandem branding + social options).
    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'password');
    final loginButton = find.text('Log in');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    // 3. The live shared grocery list.
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Bananas'), findsOneWidget);
  });
}
