import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: PrimaryButton(
          label: 'Login with Email',
          onPressed: () {
            context.read<AuthBloc>().add(
              const AuthStatusChanged(AuthStatus.authenticated),
            );
          },
        ),
      ),
    );
  }
}
