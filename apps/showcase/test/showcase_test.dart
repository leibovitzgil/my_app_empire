import 'package:feature_paywall/feature_paywall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcase/app.dart';
import 'package:showcase/injection.dart';

void main() {
  tearDown(() async => getIt.reset());

  testWidgets('shows onboarding on first launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();

    await tester.pumpWidget(const ShowcaseApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('skips onboarding once completed', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    await configureDependencies();

    await tester.pumpWidget(const ShowcaseApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Past onboarding -> auth gate shows the login screen.
    expect(find.text('Login'), findsOneWidget);
  });

  // The same funnel as integration_test/app_flow_test.dart, but headless so it
  // runs in the standard gate without a device.
  testWidgets('full funnel: onboarding -> login -> home -> paywall', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();

    await tester.pumpWidget(const ShowcaseApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'password');
    await tester.tap(find.text('Login with Email'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome! You are signed in.'), findsOneWidget);
    await tester.tap(find.text('Go Pro'));
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget);
  });
}
