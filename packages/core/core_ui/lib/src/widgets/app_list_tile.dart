import 'package:core_theme/core_theme.dart';
import 'package:core_ui/src/widgets/initials_avatar.dart';
import 'package:flutter/material.dart';

/// A themed, token-aligned wrapper around Flutter's [ListTile].
///
/// Reuses [ListTile]'s row layout rather than reinventing it — only the
/// content padding is token-driven here.
class AppListTile extends StatelessWidget {
  /// Creates an [AppListTile].
  const AppListTile({
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    super.key,
  });

  /// A widget shown before [title], e.g. an avatar or icon.
  final Widget? leading;

  /// The primary content of the tile.
  final Widget? title;

  /// Additional content shown below [title].
  final Widget? subtitle;

  /// A widget shown after [title], e.g. an icon or switch.
  final Widget? trailing;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  /// Whether the tile is interactive and rendered at full opacity.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      enabled: enabled,
    );
  }
}

/// An [AppListTile] specialised for representing a person: an
/// [InitialsAvatar] plus [name] and optional [subtitle].
///
/// The avatar is wrapped in [ExcludeSemantics] because its own semantics
/// (announcing the raw [initials] string) would be redundant — and
/// potentially confusing — alongside the screen reader already announcing
/// [name] via the tile's title. Excluding it means a screen reader announces
/// the person's name exactly once instead of "G L, Gil Leibovich".
class PersonTile extends StatelessWidget {
  /// Creates a [PersonTile].
  const PersonTile({
    required this.initials,
    required this.color,
    required this.name,
    this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  /// The short text shown in the avatar, e.g. "GL".
  final String initials;

  /// The avatar's background colour.
  final Color color;

  /// The person's display name, shown as the tile's title.
  final String name;

  /// An optional line of copy shown below [name].
  final String? subtitle;

  /// A widget shown after the title/subtitle, e.g. an icon or switch.
  final Widget? trailing;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      leading: ExcludeSemantics(
        child: InitialsAvatar(initials: initials, color: color),
      ),
      title: Text(name),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
