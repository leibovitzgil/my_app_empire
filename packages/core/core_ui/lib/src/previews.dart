import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

// Widget previews for the design system. Run `flutter widget-preview start`
// from an app (e.g. apps/showcase) to browse these hot-reloadably. They are
// excluded from release builds by the preview tooling.

@Preview(name: 'PrimaryButton • enabled')
Widget primaryButtonEnabledPreview() {
  return PrimaryButton(label: 'Continue', onPressed: () {});
}

@Preview(name: 'PrimaryButton • loading')
Widget primaryButtonLoadingPreview() {
  return const PrimaryButton(
    label: 'Continue',
    onPressed: null,
    isLoading: true,
  );
}

@Preview(name: 'PrimaryButton • disabled')
Widget primaryButtonDisabledPreview() {
  return const PrimaryButton(label: 'Continue', onPressed: null);
}

@Preview(name: 'SocialSignInButton • Google')
Widget socialGooglePreview() {
  return SocialSignInButton(
    label: 'Continue with Google',
    leading: const Text(
      'G',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: Color(0xFF4285F4),
      ),
    ),
    onPressed: () {},
  );
}

@Preview(name: 'SocialSignInButton • Apple')
Widget socialApplePreview() {
  return SocialSignInButton(
    label: 'Continue with Apple',
    icon: Icons.apple,
    onPressed: () {},
  );
}
