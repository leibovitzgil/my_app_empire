import 'package:core_ui/src/widgets/labeled_divider.dart';
import 'package:core_ui/src/widgets/primary_button.dart';
import 'package:core_ui/src/widgets/social_sign_in_button.dart';
import 'package:flutter/material.dart';

/// A bloc-agnostic, brandable sign-in scaffold.
///
/// This is the reusable presentation for a login screen: an optional [logo]
/// and [title] for branding, email + password fields, and — when the matching
/// callbacks are provided — "Continue with Google"/"Continue with Apple"
/// buttons. It owns no auth logic; callers wire the callbacks to their auth
/// layer (e.g. a feature's bloc) and pass [errorText]/[isBusy] from state.
class SignInView extends StatefulWidget {
  /// Creates a [SignInView].
  const SignInView({
    required this.onEmailSignIn,
    this.onGoogleSignIn,
    this.onAppleSignIn,
    this.logo,
    this.title,
    this.errorText,
    this.isBusy = false,
    this.submitLabel = 'Log in',
    super.key,
  });

  /// Called with the entered email and password when the primary button is
  /// tapped.
  final void Function(String email, String password) onEmailSignIn;

  /// Called when "Continue with Google" is tapped. When null the button is
  /// hidden.
  final VoidCallback? onGoogleSignIn;

  /// Called when "Continue with Apple" is tapped. When null the button is
  /// hidden.
  final VoidCallback? onAppleSignIn;

  /// Optional branding shown above the form, e.g. an `AppLogoMark`.
  final Widget? logo;

  /// Optional headline shown under the [logo], e.g. the app name.
  final String? title;

  /// An error message to surface under the fields, typically from auth state.
  final String? errorText;

  /// Whether an auth request is in flight; disables input and shows a loader.
  final bool isBusy;

  /// The primary (email) button label.
  final String submitLabel;

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitEmail() {
    widget.onEmailSignIn(_emailController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasGoogle = widget.onGoogleSignIn != null;
    final hasApple = widget.onAppleSignIn != null;
    final showSocial = hasGoogle || hasApple;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.logo != null) ...[
                    Align(child: widget.logo),
                    const SizedBox(height: 24),
                  ],
                  if (widget.title != null) ...[
                    Text(
                      widget.title!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                  ],
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
                  if (widget.errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.errorText!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: widget.submitLabel,
                    onPressed: widget.isBusy ? null : _submitEmail,
                    isLoading: widget.isBusy,
                  ),
                  if (showSocial) ...[
                    const SizedBox(height: 20),
                    const LabeledDivider(label: 'or'),
                    const SizedBox(height: 20),
                    if (hasGoogle)
                      SocialSignInButton.google(
                        onPressed: widget.onGoogleSignIn,
                      ),
                    if (hasGoogle && hasApple) const SizedBox(height: 12),
                    if (hasApple)
                      SocialSignInButton.apple(onPressed: widget.onAppleSignIn),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
