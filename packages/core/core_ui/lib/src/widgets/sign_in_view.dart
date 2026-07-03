import 'package:core_theme/core_theme.dart';
import 'package:core_ui/src/widgets/app_password_field.dart';
import 'package:core_ui/src/widgets/app_text_field.dart';
import 'package:core_ui/src/widgets/labeled_divider.dart';
import 'package:core_ui/src/widgets/primary_button.dart';
import 'package:flutter/material.dart';

/// A bloc-agnostic, brandable sign-in scaffold.
///
/// This is the reusable presentation for a login screen: an optional [logo]
/// and [title] for branding, email + password fields, and any [socialButtons]
/// the caller supplies (e.g. a Google button and the official Apple button).
/// It owns no auth logic; callers wire the callbacks to their auth layer (e.g.
/// a feature's bloc) and pass [errorText]/[isBusy] from state.
///
/// Social buttons are passed in rather than built here so each provider's
/// brand-compliant widget lives with the auth layer that owns its dependency
/// (notably Apple's required "Sign in with Apple" button).
class SignInView extends StatefulWidget {
  /// Creates a [SignInView].
  const SignInView({
    required this.onEmailSignIn,
    this.socialButtons = const <Widget>[],
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

  /// Alternative sign-in buttons shown below an "or" divider. When empty, no
  /// divider or social section is rendered.
  final List<Widget> socialButtons;

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
    final social = widget.socialButtons;
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
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (widget.title != null) ...[
                    Text(
                      widget.title!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  AppTextField(
                    controller: _emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(controller: _passwordController),
                  if (widget.errorText != null) ...[
                    const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                    Text(
                      widget.errorText!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: widget.submitLabel,
                    onPressed: widget.isBusy ? null : _submitEmail,
                    isLoading: widget.isBusy,
                  ),
                  if (social.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                    const LabeledDivider(label: 'or'),
                    const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                    for (var i = 0; i < social.length; i++) ...[
                      if (i > 0)
                        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                      social[i],
                    ],
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
