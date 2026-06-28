import 'package:flutter/material.dart';

/// An outlined "Continue with X" button for social sign-in (Google, Apple, …).
/// Matches `PrimaryButton`'s height and corner radius so auth screens stay
/// visually consistent.
class SocialSignInButton extends StatelessWidget {
  /// Creates a [SocialSignInButton].
  const SocialSignInButton({
    required this.onPressed,
    required this.label,
    this.leading,
    this.icon,
    super.key,
  });

  /// Callback when pressed; null disables the button.
  final VoidCallback? onPressed;

  /// Button text, e.g. "Continue with Google".
  final String label;

  /// A custom leading widget (e.g. a brand logo). Takes precedence over [icon].
  final Widget? leading;

  /// A Material icon shown when [leading] is null.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final lead = leading ?? (icon != null ? Icon(icon, size: 20) : null);
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (lead != null) ...[lead, const SizedBox(width: 12)],
            Text(label),
          ],
        ),
      ),
    );
  }
}
