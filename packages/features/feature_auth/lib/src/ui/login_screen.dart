import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    context.read<AuthBloc>().add(
      AuthLoginRequested(
        _emailController.text,
        _passwordController.text,
      ),
    );
  }

  void _onGooglePressed() =>
      context.read<AuthBloc>().add(AuthGoogleSignInRequested());

  void _onApplePressed() =>
      context.read<AuthBloc>().add(AuthAppleSignInRequested());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 24),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final error = state.error;
                  if (state.status == AuthStatus.failure && error != null) {
                    return Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Login with Email',
                onPressed: _onLoginPressed,
              ),
              const SizedBox(height: 20),
              const _OrDivider(),
              const SizedBox(height: 20),
              SocialSignInButton(
                label: 'Continue with Google',
                leading: const Text(
                  'G',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF4285F4),
                  ),
                ),
                onPressed: _onGooglePressed,
              ),
              const SizedBox(height: 12),
              SocialSignInButton(
                label: 'Continue with Apple',
                icon: Icons.apple,
                onPressed: _onApplePressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A horizontal "or" separator: a divider on each side of an "or" label.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(color: color)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
