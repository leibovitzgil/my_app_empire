import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:feature_grocery_list/src/ui/grocery_format.dart';
import 'package:flutter/material.dart';

/// A live "who's shopping right now" banner. Hidden when no one is shopping, so
/// it never shows stale state. Announces changes to screen readers.
class PresenceBanner extends StatelessWidget {
  /// Creates a [PresenceBanner].
  const PresenceBanner({
    required this.shoppers,
    required this.currentUser,
    super.key,
  });

  /// People currently shopping.
  final List<Shopper> shoppers;

  /// The current device user (renders as "You").
  final Collaborator currentUser;

  String _phrase() {
    final names = shoppers.map((shopper) {
      final person = shopper.collaborator;
      return person.id == currentUser.id ? 'You' : person.name;
    }).toList();
    if (names.length == 1) {
      final name = names.first;
      return name == 'You' ? 'You are shopping' : '$name is shopping';
    }
    if (names.length == 2) {
      return '${names[0]} and ${names[1]} are shopping';
    }
    return '${names[0]}, ${names[1]} +${names.length - 2} are shopping';
  }

  @override
  Widget build(BuildContext context) {
    if (shoppers.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = _phrase();
    final shown = shoppers.take(3).toList();

    return Semantics(
      liveRegion: true,
      label: text,
      child: Material(
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _LiveDot(color: scheme.tertiary),
              const SizedBox(width: 10),
              for (final shopper in shown)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: shopper.collaborator.name,
                    child: _MiniAvatar(who: shopper.collaborator),
                  ),
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.who});

  final Collaborator who;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 12,
      backgroundColor: GroceryFormat.collaboratorColor(who),
      child: Text(
        who.initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
