import 'package:core_theme/core_theme.dart';
import 'package:core_ui/src/widgets/primary_button.dart';
import 'package:flutter/material.dart';

/// A centered error placeholder: an [icon] above a [title], an optional
/// [message], and a retry button wired to [onRetry].
///
/// A design-system primitive for the failure state of any screen that loads
/// remote data. Features supply the copy and the retry action. Shares its
/// text style scale with `LoadingView`/`EmptyStateView` so all "screen
/// state" widgets read as one family.
///
/// The icon size (48) intentionally differs from `EmptyStateView`'s (72) —
/// see the note on that class for why this PR leaves the mismatch rather
/// than forcing a convergence with no clean single "correct" value.
class ErrorRetryView extends StatelessWidget {
  /// Creates an [ErrorRetryView].
  const ErrorRetryView({
    required this.title,
    required this.onRetry,
    this.message,
    this.icon = Icons.error_outline,
    this.retryLabel = 'Try again',
    super.key,
  });

  /// The primary line, e.g. "Couldn't load the list".
  final String title;

  /// Called when the user taps the retry button.
  final VoidCallback onRetry;

  /// An optional secondary line with detail (e.g. the error text).
  final String? message;

  /// The glyph shown above the text. Defaults to an error icon.
  final IconData icon;

  /// The retry button label.
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            Text(title, style: theme.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(label: retryLabel, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
