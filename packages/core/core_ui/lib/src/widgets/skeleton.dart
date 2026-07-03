import 'package:core_ui/src/theme/app_radii.dart';
import 'package:core_ui/src/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A single placeholder box used to represent content that is still loading.
///
/// Purely decorative — wrapped in `Semantics(excludeSemantics: true)` so
/// screen readers skip it. Pass [shimmer]`: false` for deterministic golden
/// captures: a repeating animation never settles.
class SkeletonBox extends StatelessWidget {
  /// Creates a [SkeletonBox].
  const SkeletonBox({
    this.width,
    this.height = 16,
    this.borderRadius = AppRadii.smRadius,
    this.shimmer = true,
    super.key,
  });

  /// The width of the box. Defaults to `null`, i.e. sized by the parent.
  final double? width;

  /// The height of the box. Defaults to 16.
  final double height;

  /// The corner radius of the box. Defaults to [AppRadii.smRadius].
  final BorderRadius borderRadius;

  /// Whether to animate a subtle repeating opacity pulse.
  ///
  /// Pass `false` for golden tests — a repeating animation never settles, so
  /// `pumpAndSettle` would hang and a mid-animation frame would be flaky.
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
    );
    return Semantics(
      excludeSemantics: true,
      child: shimmer
          ? box
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .fadeOut(
                  duration: const Duration(milliseconds: 700),
                  begin: 1,
                )
          : box,
    );
  }
}

/// A column of [SkeletonBox] placeholders standing in for a loading list.
///
/// Meant to sit inside another scrollable (e.g. a `ListView`'s empty state),
/// not to scroll itself — hence a plain `Column` rather than a `ListView`.
/// Announced once as a group (not per-item) so a screen reader doesn't read
/// out placeholder boxes one by one.
class SkeletonList extends StatelessWidget {
  /// Creates a [SkeletonList].
  const SkeletonList({
    this.itemCount = 3,
    this.itemHeight = 56,
    this.spacing = AppSpacing.md,
    this.shimmer = true,
    super.key,
  });

  /// How many placeholder rows to render. Defaults to 3.
  final int itemCount;

  /// The height of each placeholder row. Defaults to 56.
  final double itemHeight;

  /// The vertical gap between rows. Defaults to [AppSpacing.md].
  final double spacing;

  /// Whether each [SkeletonBox] animates a repeating shimmer.
  ///
  /// Pass `false` for golden tests — see [SkeletonBox.shimmer].
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading content',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < itemCount; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            SkeletonBox(
              width: double.infinity,
              height: itemHeight,
              shimmer: shimmer,
            ),
          ],
        ],
      ),
    );
  }
}
