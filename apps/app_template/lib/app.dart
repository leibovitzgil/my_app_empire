import 'package:app_template/injection.dart';
import 'package:core_ui/core_ui.dart';
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

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    // A minimal router that picks the screen from auth state. `context.watch`
    // rebuilds this builder when AuthBloc emits, so no GoRouterRefreshStream is
    // needed for this simple single-route setup.
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
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
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
