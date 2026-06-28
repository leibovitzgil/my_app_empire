import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:feature_grocery_list/src/ui/grocery_format.dart';
import 'package:flutter/material.dart';

/// Opens the low-friction flag + reaction sheet for [item]. Invokes exactly one
/// callback ([onFlag], [onClear] or [onReact]) and closes; an outside tap
/// dismisses with no action.
Future<void> showFlagSheet({
  required BuildContext context,
  required GroceryItem item,
  required Collaborator currentUser,
  required ValueChanged<ItemFlag> onFlag,
  required VoidCallback onClear,
  required VoidCallback onReact,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final flaggedByOther =
          item.flag != null &&
          item.flagBy != null &&
          item.flagBy!.id != currentUser.id;

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(item.name, style: theme.textTheme.titleMedium),
                ),
              ),
              for (final flag in ItemFlag.values)
                ListTile(
                  leading: Icon(
                    GroceryFormat.flagIcon(flag),
                    color: GroceryFormat.flagColor(flag, theme.colorScheme),
                  ),
                  title: Text(GroceryFormat.flagLabel(flag)),
                  trailing: item.flag == flag ? const Icon(Icons.check) : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onFlag(flag);
                  },
                ),
              if (flaggedByOther)
                ListTile(
                  leading: const Icon(Icons.thumb_up_alt_outlined),
                  title: const Text('On it'),
                  subtitle: Text('Reply to ${item.flagBy!.name}'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onReact();
                  },
                ),
              if (item.flag != null)
                ListTile(
                  leading: Icon(
                    Icons.flag_outlined,
                    color: theme.colorScheme.error,
                  ),
                  title: const Text('Clear flag'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onClear();
                  },
                ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                title: const Text('Delete item'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onDelete();
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
