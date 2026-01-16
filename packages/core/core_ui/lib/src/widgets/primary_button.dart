import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A primary button with standardized height, border radius and loader support.
class PrimaryButton extends StatelessWidget {
  /// Creates a [PrimaryButton].
  const PrimaryButton({
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    super.key,
  });

  /// Callback when the button is pressed.
  final VoidCallback? onPressed;

  /// The text label of the button.
  final String label;

  /// Whether to show a loading indicator instead of the label.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label).animate().fadeIn(),
      ),
    );
  }
}
