import 'package:core_ui/src/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// The semantic tone of a snackbar shown via [AppSnackbar].
enum AppSnackbarVariant {
  /// A positive outcome, e.g. "Saved successfully".
  success,

  /// A failure or problem the user needs to know about.
  error,

  /// A neutral, informational message.
  info,
}

/// A single-call snackbar helper with success/error/info variants.
///
/// Every call clears any currently-visible snackbar before showing the new
/// one, so rapid-fire calls (e.g. two failures in quick succession) never
/// stack — only the most recent message is ever visible.
///
/// Shape, floating behavior and inset padding come from `AppTheme`'s
/// `snackBarTheme` — this helper only supplies the per-call background color
/// and content, since those vary by [AppSnackbarVariant] and can't live in a
/// single static theme.
abstract final class AppSnackbar {
  /// Shows a snackbar with the given [message] and [variant].
  ///
  /// Pass [actionLabel] and [onAction] together to add a trailing action
  /// button (e.g. "Undo").
  static void show(
    BuildContext context, {
    required String message,
    AppSnackbarVariant variant = AppSnackbarVariant.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final scheme = Theme.of(context).colorScheme;
    final colors = _colorsFor(variant, scheme);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          backgroundColor: colors.background,
          content: Row(
            children: [
              Icon(_iconFor(variant), color: colors.foreground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: colors.foreground),
                ),
              ),
            ],
          ),
          action: actionLabel != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: colors.foreground,
                  onPressed: onAction ?? () {},
                )
              : null,
        ),
      );
  }

  /// Shows a success-variant snackbar.
  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      variant: AppSnackbarVariant.success,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Shows an error-variant snackbar.
  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      variant: AppSnackbarVariant.error,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Shows an info-variant snackbar.
  static void info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Resolves (background, foreground) colors for a variant.
  ///
  /// `success` intentionally maps to the *tertiary* container role rather
  /// than a literal green: the app's default seed
  /// (`ColorScheme.fromSeed(Colors.blue)`) has no semantic green in its
  /// generated palette. A future branded palette that does define a real
  /// green/success color only needs to change this one function — every
  /// call site stays the same.
  static ({Color background, Color foreground}) _colorsFor(
    AppSnackbarVariant variant,
    ColorScheme scheme,
  ) {
    return switch (variant) {
      AppSnackbarVariant.error => (
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
      ),
      AppSnackbarVariant.success => (
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
      ),
      AppSnackbarVariant.info => (
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
      ),
    };
  }

  static IconData _iconFor(AppSnackbarVariant variant) {
    return switch (variant) {
      AppSnackbarVariant.success => Icons.check_circle_outline,
      AppSnackbarVariant.error => Icons.error_outline,
      AppSnackbarVariant.info => Icons.info_outline,
    };
  }
}
