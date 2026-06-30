import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:feature_grocery_list/src/bloc/list_bloc.dart';
import 'package:feature_grocery_list/src/bloc/members_bloc.dart';
import 'package:feature_grocery_list/src/bloc/presence_bloc.dart';
import 'package:feature_grocery_list/src/data/static_item_catalog.dart';
import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:feature_grocery_list/src/domain/grocery_repository.dart';
import 'package:feature_grocery_list/src/domain/item_catalog.dart';
import 'package:feature_grocery_list/src/domain/membership_repository.dart';
import 'package:feature_grocery_list/src/domain/presence_repository.dart';
import 'package:feature_grocery_list/src/ui/attention_summary.dart';
import 'package:feature_grocery_list/src/ui/flag_sheet.dart';
import 'package:feature_grocery_list/src/ui/grocery_format.dart';
import 'package:feature_grocery_list/src/ui/item_row.dart';
import 'package:feature_grocery_list/src/ui/presence_banner.dart';
import 'package:feature_grocery_list/src/ui/recently_deleted_screen.dart';
import 'package:feature_grocery_list/src/ui/share_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Entry widget for the grocery feature: provides [ListBloc] + [PresenceBloc]
/// from the injected repositories and renders the [ListScreen]. Apps wire this
/// in with one line; tests construct it with an in-memory repo.
class GroceryListPage extends StatelessWidget {
  /// Creates a [GroceryListPage].
  const GroceryListPage({
    required this.repository,
    required this.presence,
    required this.membership,
    required this.currentUser,
    this.catalog,
    super.key,
  });

  /// The shared-list data source.
  final GroceryRepository repository;

  /// The presence data source.
  final PresenceRepository presence;

  /// The membership (sharing) data source.
  final MembershipRepository membership;

  /// The current device user.
  final Collaborator currentUser;

  /// Optional catalogue for add-item suggestions (defaults to a static one).
  final ItemCatalog? catalog;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ListBloc>(
          create: (_) =>
              ListBloc(repository: repository, currentUser: currentUser),
        ),
        BlocProvider<PresenceBloc>(
          create: (_) =>
              PresenceBloc(repository: presence, currentUser: currentUser),
        ),
        BlocProvider<MembersBloc>(
          create: (_) =>
              MembersBloc(repository: membership, currentUser: currentUser),
        ),
      ],
      child: ListScreen(catalog: catalog),
    );
  }
}

/// The core shopping screen: live shared list, presence, attention summary,
/// category-grouped items and an add-item field.
class ListScreen extends StatelessWidget {
  /// Creates a [ListScreen].
  const ListScreen({this.catalog, super.key});

  /// Catalogue used for add-item suggestions.
  final ItemCatalog? catalog;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ListBloc, ListState>(
      listenWhen: (previous, current) =>
          current.actionError != null &&
          current.actionError != previous.actionError,
      listener: (context, state) {
        final message = state.actionError;
        if (message != null) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        final list = state.list;
        return Scaffold(
          appBar: AppBar(
            title: Text(list?.name ?? 'Tandem'),
            actions: [
              if (state.status == ListStatus.ready && list != null)
                _OverflowMenu(list: list),
            ],
          ),
          body: SafeArea(
            child: switch (state.status) {
              ListStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              ListStatus.error => ErrorRetryView(
                icon: Icons.wifi_off,
                title: "Couldn't load the list",
                message: state.error,
                onRetry: () =>
                    context.read<ListBloc>().add(const ListRetryRequested()),
              ),
              ListStatus.ready => _ReadyBody(
                state: state,
                catalog: catalog ?? StaticItemCatalog(),
              ),
            },
          ),
        );
      },
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.state, required this.catalog});

  final ListState state;
  final ItemCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ListBloc>();
    final list = state.list!;
    return Column(
      children: [
        BlocBuilder<PresenceBloc, PresenceState>(
          builder: (context, presence) => PresenceBanner(
            shoppers: presence.shoppers,
            currentUser: bloc.currentUser,
          ),
        ),
        AttentionSummary(
          count: list.attentionCount,
          flagsOnly: state.flagsOnly,
          onTap: () => bloc.add(const FlagsOnlyToggled()),
        ),
        Expanded(child: _ListContent(state: state)),
        const Divider(height: 1),
        _AddItemBar(catalog: catalog),
      ],
    );
  }
}

class _ListContent extends StatelessWidget {
  const _ListContent({required this.state});

  final ListState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ListBloc>();
    final list = state.list!;
    final active = state.flagsOnly
        ? list.active.where((i) => i.isFlagged).toList()
        : list.active;
    final done = list.done;

    if (active.isEmpty && (done.isEmpty || state.flagsOnly)) {
      return EmptyStateView(
        icon: state.flagsOnly
            ? Icons.flag_outlined
            : Icons.shopping_basket_outlined,
        title: state.flagsOnly
            ? 'Nothing needs attention'
            : 'Your list is empty',
        message: state.flagsOnly
            ? 'Long-press an item to flag it'
            : 'Add the first item below',
      );
    }

    final grouped = <ItemCategory, List<GroceryItem>>{};
    for (final item in active) {
      (grouped[item.category] ??= <GroceryItem>[]).add(item);
    }

    final children = <Widget>[];
    for (final category in GroceryFormat.categoryOrder) {
      final items = grouped[category];
      if (items == null || items.isEmpty) continue;
      children.add(_CategoryHeader(category: category));
      for (final item in items) {
        children.add(_buildRow(context, bloc, item));
      }
    }

    if (done.isNotEmpty && !state.flagsOnly) {
      children.add(
        ExpansionTile(
          title: Text('Got it (${done.length})'),
          childrenPadding: EdgeInsets.zero,
          children: [for (final item in done) _buildRow(context, bloc, item)],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: children,
    );
  }

  Widget _buildRow(BuildContext context, ListBloc bloc, GroceryItem item) {
    return ItemRow(
      key: ValueKey<String>('row_${item.id}'),
      item: item,
      currentUser: bloc.currentUser,
      onAdvance: () {
        unawaited(HapticFeedback.lightImpact());
        bloc.add(StatusCycled(item.id));
        // The first status change is the implicit "I'm shopping" signal.
        context.read<PresenceBloc>().add(const ShoppingEntered());
      },
      onFlagRequested: () => _openFlagSheet(context, bloc, item),
      onDelete: () => _deleteWithUndo(context, bloc, item),
    );
  }

  void _openFlagSheet(BuildContext context, ListBloc bloc, GroceryItem item) {
    unawaited(
      showFlagSheet(
        context: context,
        item: item,
        currentUser: bloc.currentUser,
        onFlag: (flag) => bloc.add(ItemFlagged(item.id, flag)),
        onClear: () => bloc.add(FlagCleared(item.id)),
        onReact: () => bloc.add(ReactedOnIt(item.id)),
        onDelete: () => _deleteWithUndo(context, bloc, item),
      ),
    );
  }

  void _deleteWithUndo(BuildContext context, ListBloc bloc, GroceryItem item) {
    bloc.add(ItemDeleted(item.id));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.name} deleted'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => bloc.add(ItemRestored(item.id)),
          ),
        ),
      );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final ItemCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(
            GroceryFormat.categoryIcon(category),
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            GroceryFormat.categoryLabel(category),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.list});

  final GroceryList list;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ListBloc>();
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'recently_deleted':
            unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider<ListBloc>.value(
                    value: bloc,
                    child: const RecentlyDeletedScreen(),
                  ),
                ),
              ),
            );
          case 'clear_done':
            _clearDoneWithUndo(context, bloc, list);
          case 'share':
            unawaited(
              showShareSheet(
                context: context,
                bloc: context.read<MembersBloc>(),
              ),
            );
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'share',
          child: ListTile(
            leading: Icon(Icons.person_add_alt),
            title: Text('Share list'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'clear_done',
          child: ListTile(
            leading: Icon(Icons.cleaning_services_outlined),
            title: Text('Clear done items'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'recently_deleted',
          child: ListTile(
            leading: Icon(Icons.restore_from_trash_outlined),
            title: Text('Recently deleted'),
          ),
        ),
      ],
    );
  }

  void _clearDoneWithUndo(
    BuildContext context,
    ListBloc bloc,
    GroceryList list,
  ) {
    final clearedIds = list.done.map((i) => i.id).toList();
    if (clearedIds.isEmpty) return;
    bloc.add(const DoneCleared());
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Cleared ${clearedIds.length} done items'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              for (final id in clearedIds) {
                bloc.add(ItemRestored(id));
              }
            },
          ),
        ),
      );
  }
}

class _AddItemBar extends StatefulWidget {
  const _AddItemBar({required this.catalog});

  final ItemCatalog catalog;

  @override
  State<_AddItemBar> createState() => _AddItemBarState();
}

class _AddItemBarState extends State<_AddItemBar> {
  TextEditingController? _controller;

  void _submit(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    context.read<ListBloc>().add(ItemAdded(text));
    _controller?.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Autocomplete<String>(
        // The field is pinned to the bottom, so open suggestions upward.
        optionsViewOpenDirection: OptionsViewOpenDirection.up,
        optionsBuilder: (value) {
          final query = value.text.trim();
          if (query.isEmpty) return const Iterable<String>.empty();
          return widget.catalog.suggest(query);
        },
        onSelected: _submit,
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          _controller = controller;
          return TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: _submit,
            decoration: InputDecoration(
              hintText: 'Add an item…',
              prefixIcon: const Icon(Icons.add),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}
