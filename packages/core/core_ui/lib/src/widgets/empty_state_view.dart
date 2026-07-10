import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// A centered empty-state placeholder: a large faded [icon] above a [title]
/// and an optional secondary [message].
///
/// A design-system primitive so empty lists, empty search results and the like
/// look consistent. Features pass their own icon and copy. Shares its text
/// style scale with `LoadingView`/`ErrorRetryView` so all "screen state"
/// widgets read as one family.
///
/// [iconSize] intentionally differs from `ErrorRetryView`'s (72 vs 48): a
/// real call site (`feature_grocery_list`'s list screen) relies on this
/// default, and another (`recently_deleted_screen`) already overrides it to
/// 64 — there is no single value with a clean claim to "the" default, so
/// this PR leaves both as-is rather than guessing a convergence that would
/// silently change an existing screen's layout.
class EmptyStateView extends StatelessWidget {
  /// Creates an [EmptyStateView].
  const EmptyStateView({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconSize = 72,
    this.iconColor,
    this.messagePadding = EdgeInsets.zero,
    super.key,
  });

  /// The illustrative glyph shown above the text.
  final IconData icon;

  /// The primary line, e.g. "Your list is empty".
  final String title;

  /// An optional secondary line guiding the user's next action.
  final String? message;

  /// An optional call-to-action (e.g. a `PrimaryButton`) shown below the
  /// [message] — for empty states that offer a way out, like "import your
  /// first sheet".
  final Widget? action;

  /// The size of [icon]. Defaults to 72.
  final double iconSize;

  /// The colour of [icon]. Defaults to a faded primary.
  final Color? iconColor;

  /// Padding applied around [message], useful to constrain long copy.
  final EdgeInsetsGeometry messagePadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: iconColor ?? scheme.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Text(title, style: theme.textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: messagePadding,
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
