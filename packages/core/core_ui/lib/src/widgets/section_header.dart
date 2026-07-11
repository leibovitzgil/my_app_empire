import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// A low-key group label introducing a section of rows — settings groups,
/// form sections, list categories.
///
/// Pairs with `AppListTile`: place one above each group of tiles (see
/// Duet's Settings "Profile"/"Plan" groups for the canonical use).
class SectionHeader extends StatelessWidget {
  /// Creates a [SectionHeader] for [label].
  const SectionHeader(this.label, {super.key});

  /// The group's name, e.g. "Profile".
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
