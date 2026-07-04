import 'package:core_ui/src/widgets/brand_logos.dart';
import 'package:flutter/material.dart';

/// An outlined "Continue with X" button for social sign-in.
///
/// Matches `PrimaryButton`'s height and corner radius so auth screens stay
/// visually consistent. The [SocialSignInButton.google] variant carries the
/// official Google logo on the white background Google's branding requires.
///
/// There is intentionally no Apple variant here: Apple's guidelines mandate
/// their own "Sign in with Apple" button, which `feature_auth` provides via the
/// `sign_in_with_apple` package rather than a recreated mark.
class SocialSignInButton extends StatelessWidget {
  /// Creates a [SocialSignInButton].
  const SocialSignInButton({
    required this.onPressed,
    required this.label,
    this.leading,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  /// A Google sign-in button: the official multi-colour "G" on a white button,
  /// per Google's Sign in with Google branding guidelines.
  const SocialSignInButton.google({
    required VoidCallback? onPressed,
    String label = 'Continue with Google',
    Key? key,
  }) : this(
         onPressed: onPressed,
         label: label,
         leading: const GoogleLogo(),
         backgroundColor: const Color(0xFFFFFFFF),
         foregroundColor: const Color(0xFF3C4043),
         key: key,
       );

  /// Callback when pressed; null disables the button.
  final VoidCallback? onPressed;

  /// Button text, e.g. "Continue with Google".
  final String label;

  /// A custom leading widget (e.g. a brand logo). Takes precedence over [icon].
  final Widget? leading;

  /// A Material icon shown when [leading] is null.
  final IconData? icon;

  /// Optional button fill. Defaults to the theme (transparent outlined button).
  final Color? backgroundColor;

  /// Optional label/icon colour. Defaults to the theme.
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final lead = leading ?? (icon != null ? Icon(icon, size: 20) : null);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
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
