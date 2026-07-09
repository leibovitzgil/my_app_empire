import 'dart:async';

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

@Preview(name: 'LabeledToggleChip • unselected')
Widget labeledToggleChipUnselectedPreview() {
  return LabeledToggleChip(
    label: 'Teacher',
    icon: Icons.school_outlined,
    selected: false,
    onTap: () {},
  );
}

@Preview(name: 'LabeledToggleChip • selected + owned')
Widget labeledToggleChipSelectedOwnedPreview() {
  return LabeledToggleChip(
    label: 'Teacher',
    icon: Icons.school_outlined,
    selected: true,
    owned: true,
    onTap: () {},
  );
}

@Preview(name: 'InitialsAvatar')
Widget initialsAvatarPreview() {
  return const InitialsAvatar(initials: 'GL', color: Colors.indigo);
}

@Preview(name: 'AvatarStack • 2 people')
Widget avatarStackTwoPreview() {
  return const AvatarStack(
    people: [
      (initials: 'GL', color: Colors.indigo),
      (initials: 'AM', color: Colors.teal),
    ],
  );
}

@Preview(name: 'AvatarStack • 3 people')
Widget avatarStackThreePreview() {
  return const AvatarStack(
    people: [
      (initials: 'GL', color: Colors.indigo),
      (initials: 'AM', color: Colors.teal),
      (initials: 'JD', color: Colors.orange),
    ],
  );
}

@Preview(name: 'AvatarStack • overflow (+N)')
Widget avatarStackOverflowPreview() {
  return const AvatarStack(
    people: [
      (initials: 'GL', color: Colors.indigo),
      (initials: 'AM', color: Colors.teal),
      (initials: 'JD', color: Colors.orange),
      (initials: 'RK', color: Colors.pink),
      (initials: 'SM', color: Colors.blue),
    ],
  );
}

@Preview(name: 'AppCard • default')
Widget appCardDefaultPreview() {
  return AppCard(
    onTap: () {},
    child: const Text('Card content'),
  );
}

@Preview(name: 'AppCard • selected')
Widget appCardSelectedPreview() {
  return AppCard(
    selected: true,
    onTap: () {},
    child: const Text('Card content'),
  );
}

@Preview(name: 'AppListTile • default')
Widget appListTileDefaultPreview() {
  return AppListTile(
    leading: const Icon(Icons.check_circle_outline),
    title: const Text('Buy milk'),
    subtitle: const Text('Added by Gil'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {},
  );
}

@Preview(name: 'PersonTile • default')
Widget personTileDefaultPreview() {
  return PersonTile(
    initials: 'GL',
    color: Colors.indigo,
    name: 'Gil Leibovich',
    subtitle: 'gil@example.com',
    onTap: () {},
  );
}

@Preview(name: 'EmptyStateView')
Widget emptyStateViewPreview() {
  return const EmptyStateView(
    icon: Icons.shopping_basket_outlined,
    title: 'Your list is empty',
    message: 'Add the first item below',
  );
}

@Preview(name: 'EmptyStateView • with action')
Widget emptyStateViewWithActionPreview() {
  return EmptyStateView(
    icon: Icons.library_music_outlined,
    title: 'Your library is empty',
    message: 'Import a PDF to add your first sheet.',
    action: PrimaryButton(label: 'Import a sheet', onPressed: () {}),
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

@Preview(name: 'LoadingView • default')
Widget loadingViewDefaultPreview() {
  return const LoadingView();
}

@Preview(name: 'LoadingView • with label')
Widget loadingViewWithLabelPreview() {
  return const LoadingView(label: 'Loading your list…');
}

@Preview(name: 'SkeletonBox • default')
Widget skeletonBoxDefaultPreview() {
  return const SkeletonBox(width: 200);
}

@Preview(name: 'SkeletonList • default')
Widget skeletonListDefaultPreview() {
  return const SkeletonList();
}

// AppSnackbar/confirmDialog trigger overlays that need a ScaffoldMessenger
// and/or Navigator above them. Unlike the other previews in this file (which
// render a bare widget and rely on the preview harness for ancestry), these
// two wrap themselves in their own `MaterialApp` + `Scaffold` so the buttons
// work regardless of what the harness provides.

@Preview(name: 'AppSnackbar • success')
Widget appSnackbarSuccessPreview() {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) {
            return PrimaryButton(
              label: 'Show success snackbar',
              onPressed: () =>
                  AppSnackbar.success(context, 'Saved successfully'),
            );
          },
        ),
      ),
    ),
  );
}

@Preview(name: 'AppSnackbar • error')
Widget appSnackbarErrorPreview() {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) {
            return PrimaryButton(
              label: 'Show error snackbar',
              onPressed: () =>
                  AppSnackbar.error(context, 'Something went wrong'),
            );
          },
        ),
      ),
    ),
  );
}

@Preview(name: 'AppSnackbar • info')
Widget appSnackbarInfoPreview() {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) {
            return PrimaryButton(
              label: 'Show info snackbar',
              onPressed: () => AppSnackbar.info(context, 'Heads up'),
            );
          },
        ),
      ),
    ),
  );
}

@Preview(name: 'confirmDialog • default')
Widget confirmDialogDefaultPreview() {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) {
            return PrimaryButton(
              label: 'Open confirm dialog',
              onPressed: () => unawaited(
                confirmDialog(
                  context,
                  title: 'Leave without saving?',
                  message: 'Your changes will be lost.',
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

@Preview(name: 'confirmDialog • destructive')
Widget confirmDialogDestructivePreview() {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) {
            return PrimaryButton(
              label: 'Open destructive dialog',
              isDestructive: true,
              onPressed: () => unawaited(
                confirmDialog(
                  context,
                  title: 'Delete account?',
                  message: 'This cannot be undone.',
                  confirmLabel: 'Delete',
                  isDestructive: true,
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

@Preview(name: 'AppBottomSheet • default')
Widget appBottomSheetDefaultPreview() {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) {
            return PrimaryButton(
              label: 'Show bottom sheet',
              onPressed: () => unawaited(
                AppBottomSheet.show<bool>(
                  context,
                  title: 'Confirm pickup',
                  builder: (sheetContext) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: PrimaryButton(
                      label: 'Confirm',
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
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
