import 'dart:async';

import 'package:app_template/injection.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(authRepository: getIt<AuthRepository>()),
      child: const AppView(),
    );
  }
}

class AppView extends StatefulWidget {
  const AppView({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  final DeepLinkService _deepLinks = getIt<DeepLinkService>();
  late final StreamSubscription<Result<DeepLinkIntent>> _intentSubscription;
  late final GoRouter _router;
  DeepLinkIntent? _pendingIntent;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      redirect: _redirect,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const _RootScreen()),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
      ],
    );
    // A single subscription drives both updating `_pendingIntent` and
    // triggering go_router to re-run `_redirect`, in that order. Splitting
    // this into two independent subscriptions (e.g. a `GoRouterRefreshStream`
    // wired as `refreshListenable` alongside this listener) is racy: for a
    // broadcast stream, listeners fire in subscription order, so the
    // refresh-triggered redirect check could run before `_pendingIntent` is
    // actually set, silently dropping the very first navigation.
    _intentSubscription = _deepLinks.onIntent.listen((result) {
      if (result case Success<DeepLinkIntent>(:final value)) {
        setState(() => _pendingIntent = value);
        _router.refresh();
      }
    });
    unawaited(_seedInitialIntent());
  }

  Future<void> _seedInitialIntent() async {
    final result = await _deepLinks.getInitialIntent();
    if (result case Success<DeepLinkIntent>(:final value)) {
      setState(() => _pendingIntent = value);
      _router.refresh();
    }
  }

  // The factory's reference redirect-wiring pattern for deep links.
  String? _redirect(BuildContext context, GoRouterState state) {
    final pending = _pendingIntent;
    if (pending != null && pending.location != state.matchedLocation) {
      _pendingIntent = null;
      return pending.location;
    }
    return null;
  }

  @override
  void dispose() {
    unawaited(_intentSubscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}

class _RootScreen extends StatelessWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context) {
    // A simple check here just for demonstration.
    // Real apps use redirect logic.
    final authState = context.watch<AuthBloc>().state;
    if (authState.status == AuthStatus.authenticated) {
      return const HomeScreen();
    } else {
      return const LoginScreen(
        title: 'App Template',
        logo: AppLogoMark(icon: Icons.flutter_dash),
      );
    }
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome! You are authenticated.'),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Logout',
              onPressed: () {
                context.read<AuthBloc>().add(AuthLogoutRequested());
              },
            ),
          ],
        ),
      ),
    );
  }
}
