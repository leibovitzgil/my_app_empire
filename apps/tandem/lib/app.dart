import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_storage/local_storage.dart';
import 'package:tandem/injection.dart';

/// Composes the factory's packages into Tandem's funnel:
/// onboarding (first launch) -> auth -> the live shared grocery list.
class TandemApp extends StatelessWidget {
  /// Creates the [TandemApp].
  const TandemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tandem',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const _RootFlow(),
    );
  }
}

const _onboardingPages = [
  OnboardingPage(
    title: 'Shop together, live',
    description:
        'Watch items get grabbed in real time as your partner shops — '
        'so nobody buys it twice.',
    icon: Icons.shopping_cart_checkout,
  ),
  OnboardingPage(
    title: 'See who grabbed what',
    description:
        'Every item shows who added it and who put it in the cart, '
        'right there on the row.',
    icon: Icons.groups,
  ),
  OnboardingPage(
    title: 'Flag it, never miss it',
    description:
        'Out of stock? Get extra? Flag an item and your whole household '
        'sees it instantly.',
    icon: Icons.flag,
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

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return switch (state.status) {
          AuthStatus.authenticated => GroceryListPage(
            repository: getIt<GroceryRepository>(),
            presence: getIt<PresenceRepository>(),
            currentUser: GrocerySeed.you,
          ),
          AuthStatus.unauthenticated => const LoginScreen(),
          AuthStatus.failure => const LoginScreen(),
        };
      },
    );
  }
}
