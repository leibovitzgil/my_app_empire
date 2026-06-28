import 'package:flutter/material.dart';

/// A centered empty-state placeholder: a large faded [icon] above a [title]
/// and an optional secondary [message].
///
/// A design-system primitive so empty lists, empty search results and the like
/// look consistent. Features pass their own icon and copy.
class EmptyStateView extends StatelessWidget {
  /// Creates an [EmptyStateView].
  const EmptyStateView({
    required this.icon,
    required this.title,
    this.message,
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
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 4),
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
        ],
      ),
    );
  }
}
