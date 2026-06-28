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
  return SocialSignInButton.google(onPressed: () {});
}

@Preview(name: 'GoogleLogo')
Widget googleLogoPreview() {
  return const GoogleLogo(size: 40);
}

@Preview(name: 'AppLogoMark')
Widget appLogoMarkPreview() {
  return const AppLogoMark(icon: Icons.shopping_cart_checkout);
}

@Preview(name: 'LabeledDivider')
Widget labeledDividerPreview() {
  return const LabeledDivider(label: 'or');
}

@Preview(name: 'InitialsAvatar')
Widget initialsAvatarPreview() {
  return const InitialsAvatar(initials: 'GL', color: Colors.indigo);
}

@Preview(name: 'EmptyStateView')
Widget emptyStateViewPreview() {
  return const EmptyStateView(
    icon: Icons.shopping_basket_outlined,
    title: 'Your list is empty',
    message: 'Add the first item below',
  );
}

@Preview(name: 'ErrorRetryView')
Widget errorRetryViewPreview() {
  return ErrorRetryView(
    icon: Icons.wifi_off,
    title: "Couldn't load the list",
    message: 'Check your connection and try again.',
    onRetry: () {},
  );
}

@Preview(name: 'SignInView')
Widget signInViewPreview() {
  return SignInView(
    title: 'Tandem',
    logo: const AppLogoMark(icon: Icons.shopping_cart_checkout),
    onEmailSignIn: (_, _) {},
    socialButtons: [SocialSignInButton.google(onPressed: () {})],
  );
}
