import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// The auth screen, wired to [AuthBloc].
///
/// Presentation lives in core_ui's [SignInView]; this widget adapts bloc state
/// to it, dispatches events, and supplies the brand-compliant social buttons:
/// the core Google button and Apple's own [SignInWithAppleButton] (which ships
/// Apple's official artwork, as their guidelines require). Apps pass their own
/// [logo]/[title] so the same screen can front any app.
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
        // Apple's guidelines: dark UI -> white button; light UI -> black.
        final appleStyle = Theme.of(context).brightness == Brightness.dark
            ? SignInWithAppleButtonStyle.white
            : SignInWithAppleButtonStyle.black;
        return SignInView(
          logo: logo,
          title: title,
          errorText: state.status == AuthStatus.failure ? state.error : null,
          onEmailSignIn: (email, password) =>
              bloc.add(AuthLoginRequested(email, password)),
          socialButtons: [
            SocialSignInButton.google(
              onPressed: () => bloc.add(AuthGoogleSignInRequested()),
            ),
            SignInWithAppleButton(
              onPressed: () => bloc.add(AuthAppleSignInRequested()),
              text: 'Continue with Apple',
              height: 48,
              style: appleStyle,
            ),
          ],
        );
      },
    );
  }
}
