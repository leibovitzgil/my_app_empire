import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'injection.dart';

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

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    // We can use a stream for refreshListenable if AuthBloc exposes it,
    // or just rely on the fact that the Router will rebuild when dependencies change if wired up correctly.
    // For simplicity here, we might not have the full redirection logic without a Listenable.
    // But let's set up a basic router that checks auth status.

    // Note: To make GoRouter reactive to Bloc state changes, we typically need a `GoRouterRefreshStream`.
    // Since I can't import that extra utility easily, I'll keep it simple.

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            // A simple check here just for demonstration.
            // Real apps use redirect logic.
            final authState = context.watch<AuthBloc>().state;
             if (authState.status == AuthStatus.authenticated) {
               return const HomeScreen();
             } else {
               return const LoginScreen();
             }
          },
        ),
      ],
    );

    return MaterialApp.router(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
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
