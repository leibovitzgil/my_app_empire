// End-to-end flow for the showcase app. Runs headless via
// `flutter test integration_test/app_flow_test.dart`, or on a device/browser
// with screenshots via `flutter drive` (see the `flutter-e2e` skill).
import 'package:feature_paywall/feature_paywall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcase/app.dart';
import 'package:showcase/injection.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async => getIt.reset());

  testWidgets('onboarding -> login -> home -> paywall', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();

    await tester.pumpWidget(const ShowcaseApp());
    await tester.pumpAndSettle();

    // 1. Onboarding: advance through the pages to the end.
    expect(find.text('Welcome'), findsOneWidget);
    await _shot(binding, 'onboarding');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // 2. Login (shared SignInView with Showcase branding + social options).
    expect(find.text('Continue with Google'), findsOneWidget);
    await _shot(binding, 'login');
    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'password');
    final loginButton = find.text('Log in');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    // 3. Home, then open the paywall.
    expect(find.text('Welcome! You are signed in.'), findsOneWidget);
    await _shot(binding, 'home');
    await tester.tap(find.text('Go Pro'));
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget);
    await _shot(binding, 'paywall');
  });
}

/// Captures a screenshot when running under `flutter drive`; a no-op otherwise
/// (e.g. a plain `flutter test` device run, which has no screenshot channel).
Future<void> _shot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  try {
    await binding.takeScreenshot(name);
  } on Object {
    // No driver attached — skip.
  }
}
