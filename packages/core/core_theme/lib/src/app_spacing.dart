/// Shared spacing scale used across `core_ui` and consuming features.
///
/// Keeping every gap/padding/margin value on this scale (instead of ad-hoc
/// literals) is what makes spacing feel consistent app to app.
abstract final class AppSpacing {
  /// Extra-small spacing (4).
  static const double xs = 4;

  /// Small spacing (8).
  static const double sm = 8;

  /// Medium spacing (16) — the most common padding/gap value.
  static const double md = 16;

  /// Large spacing (24).
  static const double lg = 24;

  /// Extra-large spacing (32).
  static const double xl = 32;
}
