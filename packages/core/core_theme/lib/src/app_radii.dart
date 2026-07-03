import 'package:flutter/material.dart';

/// Shared corner-radius scale used across `core_ui` and consuming features.
///
/// Keeping every rounded shape on this scale (instead of ad-hoc literals)
/// is what makes corner radii feel consistent app to app.
abstract final class AppRadii {
  /// Small radius (8) — buttons, snackbars.
  static const double sm = 8;

  /// Medium radius (12) — inputs, dialogs.
  static const double md = 12;

  /// Card radius (16) — cards, bottom sheets.
  static const double card = 16;

  /// [sm] pre-wrapped as a [BorderRadius].
  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));

  /// [md] pre-wrapped as a [BorderRadius].
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));

  /// [card] pre-wrapped as a [BorderRadius].
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
}
