import 'package:flutter/material.dart';

/// A simple branded app mark: an [icon] centered on a rounded, filled square.
///
/// Apps pass their own icon and colours to brand shared scaffolds such as
/// `SignInView` without shipping an image asset, so the same login screen can
/// front many different apps.
class AppLogoMark extends StatelessWidget {
  /// Creates an [AppLogoMark] rendering [icon].
  const AppLogoMark({
    required this.icon,
    this.size = 72,
    this.background,
    this.foreground,
    super.key,
  });

  /// The glyph shown in the centre of the mark.
  final IconData icon;

  /// The width and height of the (square) mark.
  final double size;

  /// The square's fill colour. Defaults to the theme's primary container.
  final Color? background;

  /// The icon colour. Defaults to the theme's on-primary-container colour.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: foreground ?? scheme.onPrimaryContainer,
      ),
    );
  }
}
