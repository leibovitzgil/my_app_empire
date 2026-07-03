@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Onboarding welcome page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.init();

    await tester.pumpWidget(
      MaterialApp(
        // AppTheme.testTheme() is network-free (skips google_fonts) but
        // still exercises the real token-driven button/theme shape used in
        // production, so PrimaryButton renders as it does in the real app.
        theme: AppTheme.testTheme(),
        home: BlocProvider(
          create: (_) => OnboardingBloc(storage: storage),
          child: const OnboardingScreen(
            pages: [
              OnboardingPage(
                title: 'Welcome',
                description: 'A starter app built from the factory packages.',
                icon: Icons.rocket_launch,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('goldens/onboarding_welcome.png'),
    );
  });
}
