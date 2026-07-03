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

@Preview(name: 'PrimaryButton • destructive')
Widget primaryButtonDestructivePreview() {
  return PrimaryButton(
    label: 'Delete account',
    onPressed: () {},
    isDestructive: true,
  );
}

@Preview(name: 'SecondaryButton • enabled')
Widget secondaryButtonEnabledPreview() {
  return SecondaryButton(label: 'Cancel', onPressed: () {});
}

@Preview(name: 'SecondaryButton • loading')
Widget secondaryButtonLoadingPreview() {
  return const SecondaryButton(
    label: 'Cancel',
    onPressed: null,
    isLoading: true,
  );
}

@Preview(name: 'AppTextButton • enabled')
Widget appTextButtonEnabledPreview() {
  return AppTextButton(label: 'Skip', onPressed: () {});
}

@Preview(name: 'AppTextField • default')
Widget appTextFieldDefaultPreview() {
  return const AppTextField(label: 'Email', hint: 'you@example.com');
}

@Preview(name: 'AppTextField • error')
Widget appTextFieldErrorPreview() {
  return const AppTextField(label: 'Email', errorText: 'Required');
}

@Preview(name: 'AppPasswordField • default')
Widget appPasswordFieldDefaultPreview() {
  return const AppPasswordField();
}

@Preview(name: 'AppSearchField • has text')
Widget appSearchFieldHasTextPreview() {
  return AppSearchField(controller: TextEditingController(text: 'milk'));
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
