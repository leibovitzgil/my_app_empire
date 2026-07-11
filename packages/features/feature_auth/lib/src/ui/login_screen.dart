import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/ui/auth_failure_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// The auth screen, wired to [AuthBloc].
///
/// Presentation lives in core_ui's [SignInView]/[SignUpView]; this widget
/// adapts bloc state to them, dispatches events, and supplies the
/// brand-compliant social buttons: the core Google button and Apple's own
/// [SignInWithAppleButton] (which ships Apple's official artwork, as their
/// guidelines require). Apps pass their own [logo]/[title] so the same screen
/// can front any app.
///
/// Sign-in and sign-up are two modes of this one screen (toggled by the
/// views' footer links) rather than separate routes, so apps get account
/// creation without touching their routers.
class LoginScreen extends StatefulWidget {
  /// Creates a [LoginScreen], optionally branded with a [logo] and [title].
  const LoginScreen({this.logo, this.title, super.key});

  /// Optional branding shown above the form, e.g. an [AppLogoMark].
  final Widget? logo;

  /// Optional headline, e.g. the app name.
  final String? title;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  var _showSignUp = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final bloc = context.read<AuthBloc>();
        final errorText = state.status == AuthStatus.failure
            ? state.error?.message
            : null;
        if (_showSignUp) {
          return SignUpView(
            logo: widget.logo,
            title: widget.title,
            errorText: errorText,
            onSignUp: (email, password, displayName) => bloc.add(
              AuthSignUpRequested(email, password, displayName: displayName),
            ),
            onSignIn: () => setState(() => _showSignUp = false),
          );
        }
        // Apple's guidelines: dark UI -> white button; light UI -> black.
        final appleStyle = Theme.of(context).brightness == Brightness.dark
            ? SignInWithAppleButtonStyle.white
            : SignInWithAppleButtonStyle.black;
        return SignInView(
          logo: widget.logo,
          title: widget.title,
          errorText: errorText,
          onEmailSignIn: (email, password) =>
              bloc.add(AuthLoginRequested(email, password)),
          onCreateAccount: () => setState(() => _showSignUp = true),
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
