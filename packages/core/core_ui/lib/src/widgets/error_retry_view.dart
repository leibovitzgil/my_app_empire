import 'package:core_ui/src/widgets/primary_button.dart';
import 'package:flutter/material.dart';

/// A centered error placeholder: an [icon] above a [title], an optional
/// [message], and a retry button wired to [onRetry].
///
/// A design-system primitive for the failure state of any screen that loads
/// remote data. Features supply the copy and the retry action.
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(label: retryLabel, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
