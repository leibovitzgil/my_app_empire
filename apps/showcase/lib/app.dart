import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_storage/local_storage.dart';
import 'package:showcase/home_screen.dart';
import 'package:showcase/injection.dart';

/// Composes the factory's packages into a single funnel:
/// onboarding (first launch) -> auth -> home (-> paywall).
class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Showcase',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const _RootFlow(),
    );
  }
}

const _onboardingPages = [
  OnboardingPage(
    title: 'Welcome',
    description: 'A starter app built from the factory packages.',
    icon: Icons.rocket_launch,
  ),
  OnboardingPage(
    title: 'Stay on track',
    description:
        'Analytics, remote config and notifications are ready to wire.',
    icon: Icons.insights,
  ),
  OnboardingPage(
    title: 'Go Pro',
    description: 'Monetize with a paywall backed by RevenueCat.',
    icon: Icons.workspace_premium,
  ),
];

class _RootFlow extends StatefulWidget {
  const _RootFlow();

  @override
  State<_RootFlow> createState() => _RootFlowState();
}

class _RootFlowState extends State<_RootFlow> {
  late bool _onboarded =
      getIt<LocalStorageService>().getBool(OnboardingBloc.completedKey) ??
      false;

  @override
  Widget build(BuildContext context) {
    if (!_onboarded) {
      return BlocProvider(
        create: (_) => OnboardingBloc(storage: getIt<LocalStorageService>()),
        child: OnboardingScreen(
          pages: _onboardingPages,
          onCompleted: () => setState(() => _onboarded = true),
        ),
      );
    }
    return BlocProvider(
      create: (_) => AuthBloc(authRepository: getIt<AuthRepository>()),
      child: const _AuthGate(),
    );
  }
}

/// Showcase's branding for the shared sign-in screen.
const _loginScreen = LoginScreen(
  title: 'Showcase',
  logo: AppLogoMark(icon: Icons.rocket_launch),
);

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return switch (state.status) {
          AuthStatus.authenticated => const HomeScreen(),
          AuthStatus.unauthenticated => _loginScreen,
          AuthStatus.failure => _loginScreen,
        };
      },
    );
  }
}
