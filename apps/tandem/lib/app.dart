import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
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
  final DeepLinkService _deepLinks = getIt<DeepLinkService>();
  late final StreamSubscription<Result<DeepLinkIntent>> _intentSubscription;

  @override
  void initState() {
    super.initState();
    _intentSubscription = _deepLinks.onIntent.listen(_handleIntentResult);
    unawaited(_seedInitialIntent());
  }

  Future<void> _seedInitialIntent() async {
    final result = await _deepLinks.getInitialIntent();
    if (result case Success<DeepLinkIntent>()) {
      _handleIntentResult(result);
    }
  }

  void _handleIntentResult(Result<DeepLinkIntent> result) {
    // Arriving via a recognized deep link (e.g. a household invite link)
    // means the person already has context, so the marketing onboarding
    // carousel should be skipped, exactly like a returning user.
    if (result case Success<DeepLinkIntent>() when !_onboarded) {
      unawaited(
        getIt<LocalStorageService>().setBool(
          OnboardingBloc.completedKey,
          true,
        ),
      );
      setState(() => _onboarded = true);
    }
  }

  @override
  void dispose() {
    unawaited(_intentSubscription.cancel());
    super.dispose();
  }

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

/// Tandem's branding for the shared sign-in screen.
const _loginScreen = LoginScreen(
  title: 'Tandem',
  logo: AppLogoMark(icon: Icons.shopping_cart_checkout),
);

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
            membership: getIt<MembershipRepository>(),
            currentUser: GrocerySeed.you,
          ),
          AuthStatus.unauthenticated => _loginScreen,
          AuthStatus.failure => _loginScreen,
        };
      },
    );
  }
}
