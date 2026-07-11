import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_auth/src/domain/auth_account.dart';
import 'package:feature_auth/src/domain/auth_failure.dart';
import 'package:feature_auth/src/ui/auth_failure_messages.dart';
import 'package:flutter/material.dart';

/// Shows a [ReauthDialog] and resolves to true once re-authentication
/// succeeded, false when the user backed out.
///
/// Trigger reactively — after an operation failed with
/// `AuthFailure.requiresRecentLogin` — then retry the operation (the
/// account-deletion flow, M1.9, is the canonical consumer).
Future<bool> showReauthDialog(
  BuildContext context, {
  required AuthProviderKind provider,
  required Future<Result<void>> Function({String? password}) reauthenticate,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => ReauthDialog(
      provider: provider,
      reauthenticate: reauthenticate,
    ),
  );
  return confirmed ?? false;
}

/// Collects a fresh credential matched to the account's [provider]: a
/// password field for password accounts, a re-run of the OAuth flow for
/// Google/Apple ones. Failures render inline as typed human copy; a
/// user-cancelled provider flow just clears the spinner.
class ReauthDialog extends StatefulWidget {
  /// Creates a [ReauthDialog].
  const ReauthDialog({
    required this.provider,
    required this.reauthenticate,
    super.key,
  });

  /// How the signed-in account authenticates (`AuthAccount.provider`).
  final AuthProviderKind provider;

  /// The re-auth call (`AuthRepository.reauthenticate`); pass a password
  /// only for the password variant.
  final Future<Result<void>> Function({String? password}) reauthenticate;

  @override
  State<ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<ReauthDialog> {
  final _passwordController = TextEditingController();
  var _busy = false;
  String? _errorText;

  bool get _usesPassword => switch (widget.provider) {
    AuthProviderKind.password || AuthProviderKind.unknown => true,
    AuthProviderKind.google || AuthProviderKind.apple => false,
  };

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _errorText = null;
    });
    final result = _usesPassword
        ? await widget.reauthenticate(password: _passwordController.text)
        : await widget.reauthenticate();
    if (!mounted) return;
    switch (result) {
      case Success<void>():
        Navigator.of(context).pop(true);
      case ResultFailure<void>(:final error):
        final failure = error is AuthFailure
            ? error
            : AuthFailure.unknown(error);
        setState(() {
          _busy = false;
          // A user-cancelled provider sheet isn't an error — just re-arm.
          _errorText = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providerLabel = switch (widget.provider) {
      AuthProviderKind.google => 'Continue with Google',
      AuthProviderKind.apple => 'Continue with Apple',
      AuthProviderKind.password || AuthProviderKind.unknown => 'Confirm',
    };
    return AlertDialog(
      title: const Text("Confirm it's you"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _usesPassword
                ? 'Enter your password to continue.'
                : 'Re-confirm your identity to continue.',
            style: theme.textTheme.bodyMedium,
          ),
          if (_usesPassword) ...[
            const SizedBox(height: AppSpacing.md),
            AppPasswordField(controller: _passwordController),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorText!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        AppTextButton(
          onPressed: _busy ? null : _confirm,
          label: providerLabel,
          isLoading: _busy,
        ),
      ],
    );
  }
}
