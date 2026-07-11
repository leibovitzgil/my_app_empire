import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_auth/src/domain/auth_account.dart';
import 'package:feature_auth/src/domain/auth_failure.dart';
import 'package:feature_auth/src/ui/auth_failure_messages.dart';
import 'package:flutter/material.dart';

/// A dismissible "Verify your email" banner for signed-in-but-unverified
/// accounts, with a resend action.
///
/// Renders nothing while signed out, once the address is verified, or after
/// the user dismisses it (dismissal lasts for the widget's lifetime — it
/// returns on next launch until verified). On app resume it calls
/// [onRefresh] so a verification completed in the user's inbox is picked up
/// without a re-login. Nothing gates on verification in 1.0 — this banner
/// is the entire surface.
///
/// Wire it at the app layer, e.g.:
/// `EmailVerificationBanner(accounts: provider.account,
/// onResend: repo.sendEmailVerification, onRefresh: provider.refreshAccount)`.
class EmailVerificationBanner extends StatefulWidget {
  /// Creates an [EmailVerificationBanner].
  const EmailVerificationBanner({
    required this.accounts,
    required this.onResend,
    required this.onRefresh,
    super.key,
  });

  /// The signed-in account stream (`AuthAccountProvider.account`).
  final Stream<AuthAccount?> accounts;

  /// Sends the verification email (`AuthRepository.sendEmailVerification`).
  final Future<Result<void>> Function() onResend;

  /// Re-reads the profile so [accounts] re-emits with a fresh
  /// `emailVerified` (`AuthAccountProvider.refreshAccount`).
  final Future<void> Function() onRefresh;

  @override
  State<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner>
    with WidgetsBindingObserver {
  var _dismissed = false;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have clicked the verification link while the app was
    // backgrounded — refresh so the stream can clear the banner.
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.onRefresh());
    }
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    final result = await widget.onResend();
    if (!mounted) return;
    setState(() => _sending = false);
    switch (result) {
      case Success<void>():
        AppSnackbar.success(context, 'Verification email sent.');
      case ResultFailure<void>(:final error):
        AppSnackbar.error(
          context,
          (error is AuthFailure ? error.message : null) ??
              'Something went wrong. Please try again.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthAccount?>(
      stream: widget.accounts,
      builder: (context, snapshot) {
        final account = snapshot.data;
        if (_dismissed || account == null || account.emailVerified) {
          return const SizedBox.shrink();
        }
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.secondaryContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(Icons.mark_email_unread_outlined, color: scheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Verify your email — check your inbox.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  AppTextButton(
                    onPressed: _sending ? null : _resend,
                    label: 'Resend',
                    isLoading: _sending,
                  ),
                  IconButton(
                    onPressed: () => setState(() => _dismissed = true),
                    icon: const Icon(Icons.close),
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
