import 'package:core_theme/core_theme.dart';
import 'package:core_ui/src/widgets/app_password_field.dart';
import 'package:core_ui/src/widgets/app_text_button.dart';
import 'package:core_ui/src/widgets/app_text_field.dart';
import 'package:core_ui/src/widgets/primary_button.dart';
import 'package:flutter/material.dart';

/// A bloc-agnostic, brandable account-creation scaffold — `SignInView`'s
/// sibling.
///
/// Reusable presentation for a sign-up screen: optional [logo]/[title]
/// branding, an optional display-name field, email + password fields, and a
/// footer link back to sign-in ([onSignIn]). It owns no auth logic; callers
/// wire [onSignUp] to their auth layer and pass [errorText]/[isBusy] from
/// state.
class SignUpView extends StatefulWidget {
  /// Creates a [SignUpView].
  const SignUpView({
    required this.onSignUp,
    this.onSignIn,
    this.logo,
    this.title,
    this.errorText,
    this.isBusy = false,
    this.submitLabel = 'Create account',
    this.consentLabel,
    this.onConsentAccepted,
    super.key,
  });

  /// Called with the entered email, password, and display name (null when
  /// left blank) when the primary button is tapped.
  final void Function(String email, String password, String? displayName)
  onSignUp;

  /// When non-null, renders a required legal-acceptance checkbox above the
  /// submit button, labelled with this widget (typically a `RichText` linking
  /// the Terms of Service and Privacy Policy). The submit button stays
  /// disabled until the box is ticked, so an account can't be created without
  /// acceptance. When null, no checkbox is shown and sign-up is ungated —
  /// keeping this view reusable by apps that record consent elsewhere (or not
  /// at all).
  final Widget? consentLabel;

  /// Called at submit-time, immediately before [onSignUp], when a
  /// [consentLabel] is shown and its box is ticked. Apps wire this to their
  /// consent-recording seam; the tick is guaranteed because the button is
  /// otherwise disabled. Ignored when [consentLabel] is null.
  final VoidCallback? onConsentAccepted;

  /// When non-null, renders an "I already have an account" footer link that
  /// invokes it — the way back to the sign-in view.
  final VoidCallback? onSignIn;

  /// Optional branding shown above the form, e.g. an `AppLogoMark`.
  final Widget? logo;

  /// Optional headline shown under the [logo], e.g. the app name.
  final String? title;

  /// An error message to surface under the fields, typically from auth state.
  final String? errorText;

  /// Whether an auth request is in flight; disables input and shows a loader.
  final bool isBusy;

  /// The primary button label.
  final String submitLabel;

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _consentChecked = false;

  /// Whether the consent gate (if any) is satisfied. Always true when no
  /// [SignUpView.consentLabel] is shown.
  bool get _consentSatisfied => widget.consentLabel == null || _consentChecked;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    // The button is disabled unless consent is satisfied, so reaching here
    // with a consent label means the box is ticked.
    if (widget.consentLabel != null) widget.onConsentAccepted?.call();
    widget.onSignUp(
      _emailController.text,
      _passwordController.text,
      name.isEmpty ? null : name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    controller: _nameController,
                    label: 'Name (optional)',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
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
                  if (widget.consentLabel != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    CheckboxListTile(
                      key: const Key('signUpConsentCheckbox'),
                      value: _consentChecked,
                      onChanged: widget.isBusy
                          ? null
                          : (checked) => setState(
                              () => _consentChecked = checked ?? false,
                            ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: widget.consentLabel,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: widget.submitLabel,
                    onPressed: widget.isBusy || !_consentSatisfied
                        ? null
                        : _submit,
                    isLoading: widget.isBusy,
                  ),
                  if (widget.onSignIn != null) ...[
                    const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                    AppTextButton(
                      onPressed: widget.isBusy ? null : widget.onSignIn,
                      label: 'I already have an account',
                    ),
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
