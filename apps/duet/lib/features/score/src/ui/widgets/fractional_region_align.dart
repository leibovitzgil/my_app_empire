import 'package:duet/domain/domain.dart';
import 'package:flutter/material.dart';

/// Positions [child] at [region]'s centroid within an ancestor `Stack`,
/// using `Align` (rather than raw pixel `Positioned` math) so it works
/// without the ancestor's pixel size being known up front.
class FractionalRegionAlign extends StatelessWidget {
  /// Creates a [FractionalRegionAlign] for [region].
  const FractionalRegionAlign({
    required this.region,
    required this.child,
    super.key,
  });

  /// The fractional region to center [child] on.
  final Region region;

  /// The widget to position.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final centerX = region.left + region.width / 2;
    final centerY = region.top + region.height / 2;
    return Align(
      alignment: Alignment(2 * centerX - 1, 2 * centerY - 1),
      child: child,
    );
  }
}
