import 'package:flutter/material.dart';

/// A circular avatar showing a person's [initials] on a solid [color].
///
/// A design-system primitive for representing people (collaborators, members,
/// authors) consistently across features.
class InitialsAvatar extends StatelessWidget {
  /// Creates an [InitialsAvatar].
  const InitialsAvatar({
    required this.initials,
    required this.color,
    this.radius = 14,
    this.fontSize = 11,
    super.key,
  });

  /// The short text shown in the avatar, e.g. "GL".
  final String initials;

  /// The circle's background colour.
  final Color color;

  /// The avatar radius.
  final double radius;

  /// The font size of the [initials].
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
