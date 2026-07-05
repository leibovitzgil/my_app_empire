import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// A toggleable chip pairing an [icon] with a [label] — e.g. picking an ink
/// colour or filtering pieces by role.
///
/// Selection swaps the background to `colorScheme.primaryContainer`,
/// mirroring `AppCard`'s selected treatment so selection reads consistently
/// across the design system. When [owned] is true, a small pencil glyph is
/// appended to indicate the current user authored the content this chip
/// represents (e.g. their own ink layer).
class LabeledToggleChip extends StatelessWidget {
  /// Creates a [LabeledToggleChip].
  const LabeledToggleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.owned = false,
    super.key,
  });

  /// The chip's text.
  final String label;

  /// The glyph shown before [label].
  final IconData icon;

  /// Whether this chip is the active selection.
  final bool selected;

  /// Called when the chip is tapped.
  final VoidCallback onTap;

  /// Whether to show a small pencil glyph indicating the current user
  /// authored the content this chip represents.
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      borderRadius: AppRadii.smRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.smRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: TextStyle(color: foreground)),
              if (owned) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.edit, size: 12, color: foreground),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
