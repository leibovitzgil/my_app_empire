import 'package:feature_grocery_list/src/bloc/list_bloc.dart';
import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:feature_grocery_list/src/ui/grocery_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The safety net: every tombstoned item, restorable with one tap. Reads the
/// same [ListBloc] stream as the list, so restores reflect instantly.
class RecentlyDeletedScreen extends StatelessWidget {
  /// Creates a [RecentlyDeletedScreen].
  const RecentlyDeletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ListBloc>();
    return Scaffold(
      appBar: AppBar(title: const Text('Recently deleted')),
      body: BlocBuilder<ListBloc, ListState>(
        builder: (context, state) {
          final deleted = state.list?.deleted ?? const <GroceryItem>[];
          if (deleted.isEmpty) {
            return const _EmptyDeleted();
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Deleted items are kept here until you restore them.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              for (final item in deleted)
                _DeletedRow(item: item, currentUser: bloc.currentUser),
            ],
          );
        },
      ),
    );
  }
}

class _DeletedRow extends StatelessWidget {
  const _DeletedRow({required this.item, required this.currentUser});

  final GroceryItem item;
  final Collaborator currentUser;

  @override
  Widget build(BuildContext context) {
    final by = item.deletedBy;
    final who = by == null
        ? 'someone'
        : GroceryFormat.displayName(by, currentUser);
    return ListTile(
      title: Text(
        item.name,
        style: const TextStyle(decoration: TextDecoration.lineThrough),
      ),
      subtitle: Text(
        'Deleted by $who · ${GroceryFormat.relativeTime(item.updatedAt)}',
      ),
      trailing: TextButton.icon(
        icon: const Icon(Icons.restore, size: 18),
        label: const Text('Restore'),
        onPressed: () {
          context.read<ListBloc>().add(ItemRestored(item.id));
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(content: Text('${item.name} restored')),
            );
        },
      ),
    );
  }
}

class _EmptyDeleted extends StatelessWidget {
  const _EmptyDeleted();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.delete_outline,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text('Nothing deleted recently', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Items you or your co-shoppers remove show up here, so nothing '
              'is lost by accident.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
