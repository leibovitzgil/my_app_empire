import 'package:core_ui/src/theme/app_radii.dart';
import 'package:core_ui/src/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// A themed container for grouping related content, optionally tappable.
///
/// Shape, elevation and margin all come from `AppTheme`'s `cardTheme` (see
/// PR1) — this widget never overrides them. Only [selected] (background
/// swaps to `colorScheme.primaryContainer`) and [enabled] (dims + disables
/// interaction) are handled here.
///
/// When [onTap] is provided, the padded [child] is wrapped in an [InkWell]
/// so the card gets both the ripple and the `Semantics(button: true)` role
/// that [InkWell] provides automatically. Note: this widget does not enforce
/// a minimum tappable height — it respects the [child]'s intrinsic size, so
/// callers passing a tappable [onTap] are responsible for keeping [child]
/// tall enough to meet the 48dp minimum tap target.
class AppCard extends StatelessWidget {
  /// Creates an [AppCard].
  const AppCard({
    required this.child,
    this.onTap,
    this.selected = false,
    this.enabled = true,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  });

  /// The content shown inside the card.
  final Widget child;

  /// Called when the card is tapped. If `null`, the card is not
  /// interactive.
  final VoidCallback? onTap;

  /// Whether the card is highlighted as selected, swapping its background
  /// to `colorScheme.primaryContainer`.
  final bool selected;

  /// Whether the card is enabled. When `false`, the card is dimmed and
  /// cannot be tapped even if [onTap] is provided.
  final bool enabled;

  /// The padding applied around [child].
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canTap = onTap != null && enabled;

    final content = canTap
        ? InkWell(
            onTap: onTap,
            borderRadius: AppRadii.cardRadius,
            child: Padding(padding: padding, child: child),
          )
        : Padding(padding: padding, child: child);

    final card = Card(
      color: selected ? scheme.primaryContainer : null,
      child: content,
    );

    if (enabled) {
      return card;
    }
    return Opacity(
      opacity: 0.5,
      child: IgnorePointer(child: card),
    );
  }
}
