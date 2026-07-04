import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A primary button with loader support and a destructive variant.
///
/// Height, border radius and minimum tap target come from `AppTheme`'s
/// `filledButtonTheme` — this widget never hardcodes them.
class PrimaryButton extends StatelessWidget {
  /// Creates a [PrimaryButton].
  const PrimaryButton({
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.isDestructive = false,
    super.key,
  });

  /// Callback when the button is pressed.
  final VoidCallback? onPressed;

  /// The text label of the button.
  final String label;

  /// Whether to show a loading indicator instead of the label.
  final bool isLoading;

  /// Whether this button represents a destructive action, in which case it
  /// is styled with `colorScheme.error`. Pair with `confirmDialog` before
  /// invoking [onPressed].
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: isDestructive
          ? FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            )
          : null,
      child: isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label).animate().fadeIn(),
    );
  }
}
