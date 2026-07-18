import 'package:core_theme/src/app_radii.dart';
import 'package:core_theme/src/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application Theme definition.
///
/// Light and dark themes share every sub-theme (inputs, buttons, cards,
/// snackbars, dialogs, bottom sheets) via [_build] so the two never drift.
///
/// **Contrast (WCAG AA) — audited M8.5.** Every text token this theme (and
/// Duet's forced-dark reader scheme) puts on its paired surface clears AA
/// 4.5:1 for normal text, because both come from the same
/// `ColorScheme.fromSeed(Colors.blue)` tonal palette, which is generated to
/// be contrast-safe. Measured ratios (seed blue): light `onSurface`/`surface`
/// 16.3:1, light `onSurfaceVariant`/`surface` 8.9:1, light `primary`/`surface`
/// 6.1:1; dark `onSurface`/`surface` 14.3:1, dark `onSurfaceVariant`/`surface`
/// 10.9:1, and the reader's tinted status pills (`primary`/`error` text over a
/// 10%-tint fill) 9.0:1. No token needed adjusting. If you re-seed this theme
/// with a different hue, re-run the check: a low-tone seed can drop
/// `primary`-on-`surface` below 4.5:1 in one brightness.
class AppTheme {
  /// Returns the light theme.
  static ThemeData get lightTheme =>
      _build(Brightness.light, GoogleFonts.robotoTextTheme());

  /// Returns the dark theme.
  static ThemeData get darkTheme => _build(
    Brightness.dark,
    GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme),
  );

  /// A test-only seam that builds the same token-driven sub-themes as
  /// [lightTheme]/[darkTheme] but skips [GoogleFonts] (which fetches fonts
  /// over the network) in favor of the bundled default font. Use this in
  /// widget/golden tests instead of [lightTheme]/[darkTheme].
  @visibleForTesting
  static ThemeData testTheme({Brightness brightness = Brightness.light}) =>
      _build(brightness, null);

  static ThemeData _build(Brightness brightness, TextTheme? textTheme) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      inputDecorationTheme: _inputDecorationTheme(scheme),
      filledButtonTheme: _filledButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      textButtonTheme: _textButtonTheme(),
      cardTheme: _cardTheme(scheme),
      snackBarTheme: _snackBarTheme(scheme),
      dialogTheme: _dialogTheme(),
      bottomSheetTheme: _bottomSheetTheme(scheme),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(ColorScheme scheme) {
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: AppRadii.mdRadius,
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + AppSpacing.xs,
      ),
      border: border(scheme.outline),
      enabledBorder: border(scheme.outline),
      focusedBorder: border(scheme.primary, width: 2),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, width: 2),
    );
  }

  static ButtonStyle _sharedButtonStyle() => ButtonStyle(
    shape: WidgetStateProperty.all(
      const RoundedRectangleBorder(borderRadius: AppRadii.smRadius),
    ),
    minimumSize: WidgetStateProperty.all(const Size(64, 48)),
  );

  static FilledButtonThemeData _filledButtonTheme() =>
      FilledButtonThemeData(style: _sharedButtonStyle());

  static OutlinedButtonThemeData _outlinedButtonTheme() =>
      OutlinedButtonThemeData(style: _sharedButtonStyle());

  static TextButtonThemeData _textButtonTheme() =>
      TextButtonThemeData(style: _sharedButtonStyle());

  static CardThemeData _cardTheme(ColorScheme scheme) => CardThemeData(
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
    margin: EdgeInsets.zero,
    color: scheme.surfaceContainer,
    elevation: 0,
  );

  static SnackBarThemeData _snackBarTheme(ColorScheme scheme) =>
      const SnackBarThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.smRadius),
        behavior: SnackBarBehavior.floating,
        insetPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      );

  static DialogThemeData _dialogTheme() => const DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: AppRadii.mdRadius),
  );

  static BottomSheetThemeData _bottomSheetTheme(ColorScheme scheme) =>
      BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.card),
          ),
        ),
        showDragHandle: false,
        backgroundColor: scheme.surfaceContainer,
      );
}
