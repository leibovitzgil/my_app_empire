import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The auth screen, wired to [AuthBloc].
///
/// All presentation lives in core_ui's [SignInView]; this widget only adapts
/// bloc state to it and dispatches events. Apps pass their own [logo]/[title]
/// so the same screen can front any app.
class LoginScreen extends StatelessWidget {
  /// Creates a [LoginScreen], optionally branded with a [logo] and [title].
  const LoginScreen({this.logo, this.title, super.key});

  /// Optional branding shown above the form, e.g. an [AppLogoMark].
  final Widget? logo;

  /// Optional headline, e.g. the app name.
  final String? title;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final bloc = context.read<AuthBloc>();
        return SignInView(
          logo: logo,
          title: title,
          errorText: state.status == AuthStatus.failure ? state.error : null,
          onEmailSignIn: (email, password) =>
              bloc.add(AuthLoginRequested(email, password)),
          onGoogleSignIn: () => bloc.add(AuthGoogleSignInRequested()),
          onAppleSignIn: () => bloc.add(AuthAppleSignInRequested()),
        );
      },
    );
  }
}
