import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:feature_grocery_list/src/ui/grocery_format.dart';
import 'package:flutter/material.dart';

/// A single grocery row: status icon (tap to advance), name, an inline
/// attribution chip ("In cart · Dana · just now"), an optional flag chip and
/// "On it" reaction, plus a who-set-it avatar. Swipe left to delete.
///
/// All behaviour is delegated to callbacks so the row stays pure and testable —
/// the haptic/animation seam lives at [onAdvance]'s call site.
class ItemRow extends StatelessWidget {
  /// Creates an [ItemRow].
  const ItemRow({
    required this.item,
    required this.currentUser,
    required this.onAdvance,
    required this.onFlagRequested,
    required this.onDelete,
    super.key,
  });

  /// The item to render.
  final GroceryItem item;

  /// The current device user (resolves "you" vs a member name).
  final Collaborator currentUser;

  /// Called when the row is tapped to advance its status.
  final VoidCallback onAdvance;

  /// Called on long-press to open the flag/reaction sheet.
  final VoidCallback onFlagRequested;

  /// Called when the row is swiped away (delete).
  final VoidCallback onDelete;

  String get _attribution {
    if (item.status == ItemStatus.needed) {
      final who = GroceryFormat.displayName(item.addedBy, currentUser);
      return 'Added by $who · ${GroceryFormat.relativeTime(item.addedAt)}';
    }
    final verb = GroceryFormat.statusVerb(item.status);
    final who = GroceryFormat.displayName(item.statusBy, currentUser);
    return '$verb · $who · ${GroceryFormat.relativeTime(item.statusAt)}';
  }

  String? get _reactionText {
    if (item.reactions.isEmpty) return null;
    final first = GroceryFormat.displayName(item.reactions.first, currentUser);
    final extra = item.reactions.length - 1;
    return extra > 0 ? '$first +$extra · On it' : '$first · On it';
  }

  String get _semanticLabel {
    final parts = <String>[item.name, GroceryFormat.statusVerb(item.status)];
    final flag = item.flag;
    if (flag != null) parts.add('flagged ${GroceryFormat.flagLabel(flag)}');
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDone = item.status == ItemStatus.done;
    final statusColor = switch (item.status) {
      ItemStatus.needed => scheme.outline,
      ItemStatus.inCart => scheme.primary,
      ItemStatus.done => scheme.tertiary,
    };
    final nameStyle = theme.textTheme.bodyLarge?.copyWith(
      decoration: isDone ? TextDecoration.lineThrough : null,
      color: isDone ? scheme.onSurface.withValues(alpha: 0.5) : null,
    );
    final reaction = _reactionText;

    return Semantics(
      button: true,
      label: _semanticLabel,
      child: Dismissible(
        key: ValueKey<String>('dismiss_${item.id}'),
        direction: DismissDirection.endToStart,
        // Return false so Dismissible doesn't remove the row itself: the delete
        // flows through the bloc/stream, which rebuilds the list without it.
        confirmDismiss: (_) async {
          onDelete();
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          color: scheme.errorContainer,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
        ),
        child: InkWell(
          onTap: onAdvance,
          onLongPress: onFlagRequested,
          child: Container(
            color: item.status == ItemStatus.inCart
                ? scheme.primaryContainer.withValues(alpha: 0.25)
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      GroceryFormat.statusIcon(item.status),
                      key: ValueKey<ItemStatus>(item.status),
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (item.flag != null) ...[
                            _FlagChip(flag: item.flag!),
                            const SizedBox(width: 8),
                          ],
                          Flexible(child: Text(item.name, style: nameStyle)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _attribution,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (reaction != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '👍 $reaction',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Avatar(
                  who: item.status == ItemStatus.needed
                      ? item.addedBy
                      : item.statusBy,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlagChip extends StatelessWidget {
  const _FlagChip({required this.flag});

  final ItemFlag flag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = GroceryFormat.flagColor(flag, scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(GroceryFormat.flagIcon(flag), size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            GroceryFormat.flagLabel(flag),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.who});

  final Collaborator who;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: GroceryFormat.collaboratorColor(who),
      child: Text(
        who.initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
