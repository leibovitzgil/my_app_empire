import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/library/src/bloc/library_bloc.dart';
import 'package:duet/features/library/src/data/pdf_file_picker.dart';
import 'package:duet/features/library/src/ui/import_piece_screen.dart';
import 'package:duet/features/library/src/ui/library_format.dart';
import 'package:duet/features/library/src/ui/piece_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

/// Builds the [AvatarStackPerson] list for the participants on [piece] OTHER
/// than [currentUserId] — the owner plus every collaborator, minus the
/// viewer. For a sheet you own that's your collaborators; for a sheet shared
/// with you that's the owner plus any other collaborators.
List<AvatarStackPerson> _otherParticipantAvatars(
  Piece piece,
  String currentUserId,
) => [
  for (final id in piece.participantIds)
    if (id != currentUserId)
      (
        initials: LibraryFormat.initialsFor(id),
        color: Color(LibraryFormat.colorValueFor(id)),
      ),
];

/// The number of Stage-gallery grid columns for a body of [width] logical
/// pixels: 2 below 600, 3 from 600–899, 4 from 900–1023, 5 from 1024 up. A
/// small pure function so the responsive breakpoints are unit-testable
/// without pumping a widget tree.
int columnsForWidth(double width) {
  if (width >= 1024) return 5;
  if (width >= 900) return 4;
  if (width >= 600) return 3;
  return 2;
}

/// Entry widget for the library feature: provides [LibraryBloc] and renders
/// [LibraryHomeScreen]. Apps wire this in with one line, supplying the
/// concrete repositories/services and the cross-feature navigation callbacks
/// this package can't own directly (see [onOpenScore]/[onInvitePiece]).
class LibraryPage extends StatelessWidget {
  /// Creates a [LibraryPage].
  const LibraryPage({
    required this.pieceRepository,
    required this.renderService,
    required this.binaryStore,
    required this.currentUserId,
    required this.onOpenScore,
    required this.appName,
    this.onInvitePiece,
    this.onOpenCollaborators,
    this.onOpenSettings,
    this.onExportBundle,
    this.onImportBundle,
    this.filePicker,
    this.currentUserName,
    this.onPasteInviteLink,
    super.key,
  });

  /// The shared piece data source.
  final PieceRepository pieceRepository;

  /// Used by the import flow to validate a picked PDF opens cleanly.
  final PdfRenderService renderService;

  /// Uploads a created piece's base PDF with progress (see the import flow).
  final PieceBinaryStore binaryStore;

  /// The signed-in user's id.
  final String currentUserId;

  /// Called to navigate to `feature_score`'s `ScoreViewerScreen` for the
  /// given piece. A callback rather than a direct dependency: `feature_library`
  /// and `feature_score` are siblings that must not depend on each other, so
  /// the app-glue layer owns the actual route.
  final void Function(Piece piece) onOpenScore;

  /// Called when the user wants to invite a friend to a sheet they own (from
  /// Piece Detail, or the Stage gallery's quick-actions sheet). A callback for
  /// the same reason as [onOpenScore]: the invite sheet lives in
  /// `feature_pairing`, a sibling package. `null` hides the action entirely
  /// (e.g. an app that hasn't wired pairing yet).
  final void Function(Piece piece)? onInvitePiece;

  /// Called when the user taps a piece's "Collaborators (N)" tile in Piece
  /// Detail, to navigate to `feature_pairing`'s Collaborators screen. A
  /// callback for the same reason as [onOpenScore]/[onInvitePiece]. `null`
  /// hides the tile entirely (see `PieceDetailScreen.onOpenCollaborators`).
  final void Function(Piece piece)? onOpenCollaborators;

  /// Called to export a piece's annotations as a `.duet` review bundle and
  /// share it — the offline escape hatch surfaced from Piece Detail (M4.2). A
  /// callback for the same reason as [onOpenScore]. `null` hides the action.
  final void Function(Piece piece)? onExportBundle;

  /// Called to pick and import a `.duet` review bundle from Piece Detail. See
  /// [onExportBundle]. `null` hides the action.
  final VoidCallback? onImportBundle;

  /// Called when the user wants to open the app's settings screen. A
  /// callback for the same reason as [onOpenScore]/[onInvitePiece]: settings
  /// lives in `feature_settings`, a sibling package this one must not depend
  /// on. `null` hides the settings action entirely (e.g. an app that hasn't
  /// wired settings yet).
  final VoidCallback? onOpenSettings;

  /// Picks a PDF for the import flow. Defaults to [pickPdfFile]; override in
  /// tests to avoid the platform channel.
  final PdfFilePicker? filePicker;

  /// The signed-in user's display name, if known — sourced from auth identity
  /// and attached to any sheet created via the import flow (see
  /// `ImportPieceBloc.ownerName`). `null` falls back to an initials-from-id
  /// placeholder wherever this sheet's owner is shown.
  final String? currentUserName;

  /// The product name shown as the header's eyebrow (e.g. "DUET"). Supplied
  /// by the app so this shared slice isn't tied to one brand — mirrors
  /// [currentUserName]'s app-supplied convention.
  final String appName;

  /// Called when the user taps "Paste an invite link" from the empty-library
  /// state. `null` shows an info placeholder snackbar instead (the same
  /// treatment as the not-yet-built Collections/Favorites actions) — no app
  /// has wired a paste-link flow yet.
  final void Function()? onPasteInviteLink;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LibraryBloc>(
      create: (_) => LibraryBloc(
        pieceRepository: pieceRepository,
        currentUserId: currentUserId,
      )..add(const LibraryStarted()),
      child: LibraryHomeScreen(
        pieceRepository: pieceRepository,
        renderService: renderService,
        binaryStore: binaryStore,
        currentUserId: currentUserId,
        onOpenScore: onOpenScore,
        onInvitePiece: onInvitePiece,
        onOpenCollaborators: onOpenCollaborators,
        onOpenSettings: onOpenSettings,
        onExportBundle: onExportBundle,
        onImportBundle: onImportBundle,
        filePicker: filePicker,
        currentUserName: currentUserName,
        appName: appName,
        onPasteInviteLink: onPasteInviteLink,
      ),
    );
  }
}

/// The unified Home / Sheet Library body: a dark, cover-forward "Stage" grid
/// gallery over the same piece stream. Reads [LibraryBloc] from context
/// (provided by [LibraryPage]).
class LibraryHomeScreen extends StatefulWidget {
  /// Creates a [LibraryHomeScreen].
  const LibraryHomeScreen({
    required this.pieceRepository,
    required this.renderService,
    required this.binaryStore,
    required this.currentUserId,
    required this.onOpenScore,
    required this.appName,
    this.onInvitePiece,
    this.onOpenCollaborators,
    this.onOpenSettings,
    this.onExportBundle,
    this.onImportBundle,
    this.filePicker,
    this.currentUserName,
    this.onPasteInviteLink,
    this.now,
    super.key,
  });

  /// The shared piece data source.
  final PieceRepository pieceRepository;

  /// Used by the import flow to validate a picked PDF opens cleanly.
  final PdfRenderService renderService;

  /// See [LibraryPage.binaryStore].
  final PieceBinaryStore binaryStore;

  /// The signed-in user's id.
  final String currentUserId;

  /// See [LibraryPage.onOpenScore].
  final void Function(Piece piece) onOpenScore;

  /// See [LibraryPage.onInvitePiece].
  final void Function(Piece piece)? onInvitePiece;

  /// See [LibraryPage.onOpenCollaborators].
  final void Function(Piece piece)? onOpenCollaborators;

  /// See [LibraryPage.onExportBundle].
  final void Function(Piece piece)? onExportBundle;

  /// See [LibraryPage.onImportBundle].
  final VoidCallback? onImportBundle;

  /// See [LibraryPage.onOpenSettings].
  final VoidCallback? onOpenSettings;

  /// See [LibraryPage.filePicker].
  final PdfFilePicker? filePicker;

  /// See [LibraryPage.currentUserName].
  final String? currentUserName;

  /// See [LibraryPage.appName].
  final String appName;

  /// See [LibraryPage.onPasteInviteLink].
  final void Function()? onPasteInviteLink;

  /// A test/golden-only clock seam: fixes "now" for the header greeting and
  /// every cover card's relative-time meta, so output is deterministic.
  /// Mirrors [LibraryFormat.relativeTime]'s own `now` parameter. `null` (the
  /// default) uses the real wall clock.
  @visibleForTesting
  final DateTime? now;

  @override
  State<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends State<LibraryHomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    context.read<LibraryBloc>().add(
      LibrarySearchChanged(_searchController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, state) {
        final showFab =
            state.status == LibraryStatus.ready && state.pieces.isNotEmpty;
        final showFilterBar = showFab && state.query.trim().isEmpty;
        return Scaffold(
          floatingActionButton: showFab ? _buildFab(context) : null,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = columnsForWidth(constraints.maxWidth);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      appName: widget.appName,
                      greeting: _greetingFor(state),
                      currentUserId: widget.currentUserId,
                      searchController: _searchController,
                      searchFocusNode: _searchFocusNode,
                      onOpenSettings: widget.onOpenSettings,
                      // Search is hidden until the library has content (mockup
                      // 3b: "search + chips hidden until there is content"),
                      // matching the filter bar's gating above.
                      showSearch: showFab,
                    ),
                    if (showFilterBar) _FilterSortBar(state: state),
                    Expanded(child: _buildBody(context, state, columns)),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _greetingFor(LibraryState state) {
    if (state.status == LibraryStatus.ready && state.pieces.isEmpty) {
      return LibraryFormat.welcome(widget.currentUserName);
    }
    return LibraryFormat.greetingFor(widget.currentUserName, now: widget.now);
  }

  Widget _buildFab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.sizeOf(context).width < 360;
    if (isCompact) {
      return FloatingActionButton(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        tooltip: 'Import a sheet',
        onPressed: () => unawaited(_openImportFlow(context)),
        child: const Icon(Icons.add),
      );
    }
    return FloatingActionButton.extended(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      tooltip: 'Import a sheet',
      icon: const Icon(Icons.add),
      label: const Text('Import a sheet'),
      onPressed: () => unawaited(_openImportFlow(context)),
    );
  }

  Widget _buildBody(BuildContext context, LibraryState state, int columns) {
    switch (state.status) {
      case LibraryStatus.loading:
        return _LoadingGrid(columns: columns);
      case LibraryStatus.failure:
        return ErrorRetryView(
          title: "Couldn't load your library",
          message: state.error,
          onRetry: () =>
              context.read<LibraryBloc>().add(const LibraryStarted()),
        );
      case LibraryStatus.ready:
        return _readyBody(context, state, columns);
    }
  }

  Widget _readyBody(BuildContext context, LibraryState state, int columns) {
    if (state.pieces.isEmpty) {
      return _EmptyLibraryView(
        onImport: () => unawaited(_openImportFlow(context)),
        onPasteInviteLink: () => _handlePasteInviteLink(context),
      );
    }
    if (state.query.trim().isNotEmpty) {
      return _SearchResults(
        state: state,
        currentUserId: widget.currentUserId,
        now: widget.now,
        onOpenScore: (piece) => _openScore(context, piece),
      );
    }
    if (state.filter == LibraryFilter.favorites) {
      return const EmptyStateView(
        icon: Icons.star_outline,
        title: 'Favorites coming soon',
      );
    }
    return _GalleryBody(
      state: state,
      columns: columns,
      currentUserId: widget.currentUserId,
      now: widget.now,
      onOpenScore: (piece) => _openScore(context, piece),
      onShowQuickActions: (piece) =>
          unawaited(_showSheetQuickActions(context, piece)),
    );
  }

  void _handlePasteInviteLink(BuildContext context) {
    final onPasteInviteLink = widget.onPasteInviteLink;
    if (onPasteInviteLink != null) {
      onPasteInviteLink();
    } else {
      AppSnackbar.info(context, 'Coming soon');
    }
  }

  void _openScore(BuildContext context, Piece piece) {
    // Opening the reader is what "views" a piece — optimistically clear its
    // unread dot here (the reader itself persists the watermark, M4.3).
    // Opening the *detail* screen deliberately does not, so a piece stays
    // flagged new until it's actually read.
    context.read<LibraryBloc>().add(PieceViewed(piece.id));
    widget.onOpenScore(piece);
  }

  void _openDetail(BuildContext context, Piece piece) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PieceDetailPage(
            pieceRepository: widget.pieceRepository,
            currentUserId: widget.currentUserId,
            pieceId: piece.id,
            onOpenScore: widget.onOpenScore,
            onInvitePiece: widget.onInvitePiece,
            onOpenCollaborators: widget.onOpenCollaborators,
            onExportBundle: widget.onExportBundle,
            onImportBundle: widget.onImportBundle,
          ),
        ),
      ),
    );
  }

  Future<void> _openImportFlow(BuildContext context) async {
    final piece = await Navigator.of(context).push<Piece>(
      MaterialPageRoute<Piece>(
        builder: (_) => ImportPiecePage(
          pieceRepository: widget.pieceRepository,
          renderService: widget.renderService,
          binaryStore: widget.binaryStore,
          filePicker: widget.filePicker,
          ownerName: widget.currentUserName,
        ),
      ),
    );
    if (piece != null) widget.onOpenScore(piece);
  }

  Future<void> _showSheetQuickActions(
    BuildContext context,
    Piece piece,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final isOwner = piece.ownerId == widget.currentUserId;
    await AppBottomSheet.show<void>(
      context,
      title: piece.title,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('Open score'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _openScore(context, piece);
            },
          ),
          if (isOwner && widget.onInvitePiece != null)
            ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: const Text('Invite a partner'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                widget.onInvitePiece!(piece);
              },
            ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('Add to collection'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              AppSnackbar.info(context, 'Collections coming soon');
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_border),
            title: const Text('Add to favorites'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              AppSnackbar.info(context, 'Favorites coming soon');
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Details'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _openDetail(context, piece);
            },
          ),
          if (isOwner)
            ListTile(
              leading: Icon(Icons.delete_outline, color: scheme.error),
              title: Text(
                'Delete sheet',
                style: TextStyle(color: scheme.error),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_confirmDelete(context, piece));
              },
            ),
          if (!isOwner)
            ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text(
                'Leave sheet',
                style: TextStyle(color: scheme.error),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_confirmLeave(context, piece));
              },
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Piece piece) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete this sheet?',
      message: 'This permanently deletes the sheet for everyone on it.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    final result = await widget.pieceRepository.deletePiece(piece.id);
    if (!context.mounted) return;
    switch (result) {
      case Success<void>():
        AppSnackbar.success(context, '${piece.title} deleted');
      case ResultFailure<void>(:final error):
        AppSnackbar.error(context, '$error');
    }
  }

  Future<void> _confirmLeave(BuildContext context, Piece piece) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Leave this sheet?',
      message: "You'll lose access until invited again.",
      confirmLabel: 'Leave',
      isDestructive: true,
    );
    if (!confirmed) return;
    final result = await widget.pieceRepository.leavePiece(piece.id);
    if (!context.mounted) return;
    switch (result) {
      case Success<void>():
        AppSnackbar.success(context, 'Left ${piece.title}');
      case ResultFailure<void>(:final error):
        AppSnackbar.error(context, '$error');
    }
  }
}

/// The header row: eyebrow + greeting on the left, search/settings/avatar on
/// the right. Always shown (across every [LibraryStatus]) — only the
/// [greeting] text and the filter/sort bar below it change per state.
class _Header extends StatelessWidget {
  const _Header({
    required this.appName,
    required this.greeting,
    required this.currentUserId,
    required this.searchController,
    required this.searchFocusNode,
    required this.onOpenSettings,
    required this.showSearch,
  });

  final String appName;
  final String greeting;
  final String currentUserId;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback? onOpenSettings;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w300,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (showSearch) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: AppSearchField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  hint: 'Search your library',
                ),
              ),
            ),
          ],
          if (onOpenSettings != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: onOpenSettings,
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: const CircleBorder(),
                side: BorderSide(color: scheme.outlineVariant),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          ExcludeSemantics(
            child: InitialsAvatar(
              initials: LibraryFormat.initialsFor(currentUserId),
              color: Color(LibraryFormat.colorValueFor(currentUserId)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The scrollable row of filter chips plus the trailing sort control. Shown
/// only when ready with content and no active search (see
/// `_LibraryHomeScreenState.build`).
class _FilterSortBar extends StatelessWidget {
  const _FilterSortBar({required this.state});

  final LibraryState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LibraryBloc>();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      // The sort control is capped at 60% of the bar and its label ellipsizes
      // (see `_SortControl`) so a large text scale can't force it wider than
      // the bar and overflow the row — at normal scale it stays tight to its
      // content, well under the cap even on a 320dp phone.
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: state.filter == LibraryFilter.all,
                      onSelected: () => bloc.add(
                        const LibraryFilterChanged(LibraryFilter.all),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FilterChip(
                      label: 'My sheets',
                      selected: state.filter == LibraryFilter.mine,
                      onSelected: () => bloc.add(
                        const LibraryFilterChanged(LibraryFilter.mine),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FilterChip(
                      label: 'Shared with me',
                      selected: state.filter == LibraryFilter.shared,
                      showDot: state.unreadSharedCount > 0,
                      onSelected: () => bloc.add(
                        const LibraryFilterChanged(LibraryFilter.shared),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FilterChip(
                      label: 'Favorites',
                      selected: state.filter == LibraryFilter.favorites,
                      onSelected: () => bloc.add(
                        const LibraryFilterChanged(LibraryFilter.favorites),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 0.6,
              ),
              child: _SortControl(sort: state.sort),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.showDot = false,
  });

  final String label;
  final bool selected;
  final bool showDot;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: showDot
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.circle, size: 6, color: scheme.error),
              ],
            )
          : Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _SortControl extends StatelessWidget {
  const _SortControl({required this.sort});

  final LibrarySort sort;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<LibrarySort>(
      tooltip: 'Sort',
      onSelected: (value) =>
          context.read<LibraryBloc>().add(LibrarySortChanged(value)),
      itemBuilder: (context) => [
        for (final option in LibrarySort.values)
          PopupMenuItem<LibrarySort>(
            value: option,
            child: Text(_label(option)),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_vert, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              _label(sort),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }

  String _label(LibrarySort sort) => switch (sort) {
    LibrarySort.recentlyUpdated => 'Recently updated',
    LibrarySort.recentlyAdded => 'Recently added',
    LibrarySort.title => 'Title',
  };
}

/// A skeleton placeholder tiled into the SAME grid delegate/columns the ready
/// gallery uses, so the loading state doesn't jump-cut into a different
/// shape once content arrives.
class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading your library',
      excludeSemantics: true,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 4 / 5.2,
        ),
        itemCount: columns * 2,
        itemBuilder: (context, index) =>
            const SkeletonBox(borderRadius: AppRadii.cardRadius),
      ),
    );
  }
}

class _EmptyLibraryView extends StatelessWidget {
  const _EmptyLibraryView({
    required this.onImport,
    required this.onPasteInviteLink,
  });

  final VoidCallback onImport;
  final VoidCallback onPasteInviteLink;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.library_music_outlined,
      title: 'Your library is empty',
      message:
          'Import a PDF to add your first sheet, or open an invite '
          'link from a friend to see what they’ve shared.',
      messagePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      action: _EmptyActions(
        onImport: onImport,
        onPasteInviteLink: onPasteInviteLink,
      ),
    );
  }
}

/// A responsive Row (wide) / Column (narrow) of the empty-library actions.
class _EmptyActions extends StatelessWidget {
  const _EmptyActions({
    required this.onImport,
    required this.onPasteInviteLink,
  });

  final VoidCallback onImport;
  final VoidCallback onPasteInviteLink;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final importButton = PrimaryButton(
          label: 'Import a sheet',
          onPressed: onImport,
        );
        final pasteButton = SecondaryButton(
          label: 'Paste an invite link',
          onPressed: onPasteInviteLink,
        );
        if (constraints.maxWidth >= 480) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              importButton,
              const SizedBox(width: AppSpacing.sm),
              pasteButton,
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            importButton,
            const SizedBox(height: AppSpacing.sm),
            pasteButton,
          ],
        );
      },
    );
  }
}

/// The `all`-filter shelves ("My sheets" / "Shared with me") or, for any
/// other filter, a single grid of [LibraryState.visiblePieces].
class _GalleryBody extends StatelessWidget {
  const _GalleryBody({
    required this.state,
    required this.columns,
    required this.currentUserId,
    required this.now,
    required this.onOpenScore,
    required this.onShowQuickActions,
  });

  final LibraryState state;
  final int columns;
  final String currentUserId;
  final DateTime? now;
  final void Function(Piece piece) onOpenScore;
  final void Function(Piece piece) onShowQuickActions;

  @override
  Widget build(BuildContext context) {
    if (state.filter != LibraryFilter.all) {
      final pieces = state.visiblePieces;
      if (pieces.isEmpty) return _FilterEmptyState(filter: state.filter);
      return CustomScrollView(
        slivers: [
          _grid(pieces),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      );
    }

    final mine = state.visibleMyPieces;
    final shared = state.visibleSharedPieces;
    return CustomScrollView(
      slivers: [
        if (mine.isNotEmpty) ...[
          const _SectionHeader(label: 'My sheets'),
          _grid(mine),
        ],
        if (shared.isNotEmpty) ...[
          _SectionHeader(
            label: 'Shared with me',
            badgeCount: state.unreadSharedCount,
          ),
          _grid(shared),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }

  Widget _grid(List<Piece> pieces) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 4 / 5.2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final piece = pieces[index];
            return _SheetCoverCard(
              key: ValueKey<String>('cover_${piece.id}'),
              piece: piece,
              state: state,
              currentUserId: currentUserId,
              now: now,
              onOpenScore: onOpenScore,
              onShowQuickActions: onShowQuickActions,
            );
          },
          childCount: pieces.length,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.badgeCount = 0});

  final String label;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Flexible + ellipsis so a large text scale shrinks the label
            // rather than pushing the count pill off the row's right edge.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              _CountPill(count: badgeCount),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        '$count new',
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The empty view for a single-piece-set filter (`mine`/`shared`) that
/// currently resolves to nothing. `all`/`favorites` never reach this widget
/// (see `_LibraryHomeScreenState._readyBody`/`_GalleryBody.build`) — those
/// arms exist only so the switch stays exhaustive.
class _FilterEmptyState extends StatelessWidget {
  const _FilterEmptyState({required this.filter});

  final LibraryFilter filter;

  @override
  Widget build(BuildContext context) {
    return switch (filter) {
      LibraryFilter.shared => const EmptyStateView(
        icon: Icons.inbox_outlined,
        title: 'Nothing shared yet',
        message: 'Sheets your friends share with you will appear here.',
        messagePadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      LibraryFilter.mine => const EmptyStateView(
        icon: Icons.library_music_outlined,
        title: 'No sheets of your own yet',
        message: 'Import a PDF to add your first sheet.',
        messagePadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      LibraryFilter.all || LibraryFilter.favorites => const SizedBox.shrink(),
    };
  }
}

/// Title-matched search results, reusing the pre-Stage-gallery per-role
/// subtitle copy verbatim.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.state,
    required this.currentUserId,
    required this.now,
    required this.onOpenScore,
  });

  final LibraryState state;
  final String currentUserId;
  final DateTime? now;
  final void Function(Piece piece) onOpenScore;

  @override
  Widget build(BuildContext context) {
    // Global search — spans the whole library, not the active filter (the
    // chips are hidden during search), so a query always finds every match.
    final pieces = state.searchResults;
    final query = state.query.trim();
    if (pieces.isEmpty) return _NoMatches(query: query);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: pieces.length,
      itemBuilder: (context, index) {
        final piece = pieces[index];
        final isOwned = piece.ownerId == currentUserId;
        final subtitle = isOwned
            ? 'Updated ${LibraryFormat.relativeTime(piece.updatedAt, now: now)}'
            : 'Shared by ${piece.ownerName ?? 'Owner'} · '
                  '${LibraryFormat.relativeTime(piece.updatedAt, now: now)}';
        return AppListTile(
          title: _highlightedTitle(context, piece.title, query),
          subtitle: Text(subtitle),
          onTap: () => onOpenScore(piece),
        );
      },
    );
  }

  Widget _highlightedTitle(BuildContext context, String title, String query) {
    if (query.isEmpty) return Text(title);
    final lowerTitle = title.toLowerCase();
    final matchStart = lowerTitle.indexOf(query.toLowerCase());
    if (matchStart < 0) return Text(title);
    final matchEnd = matchStart + query.length;
    final scheme = Theme.of(context).colorScheme;
    final highlightStyle = TextStyle(
      color: scheme.primary,
      fontWeight: FontWeight.w700,
    );
    return Text.rich(
      TextSpan(
        children: [
          if (matchStart > 0) TextSpan(text: title.substring(0, matchStart)),
          TextSpan(
            text: title.substring(matchStart, matchEnd),
            style: highlightStyle,
          ),
          if (matchEnd < title.length)
            TextSpan(text: title.substring(matchEnd)),
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Icon(Icons.search_off, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'No matches for “$query”',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

const _paperColor = Color(0xFFF4F2EC);
const _staffLineColor = Color(0xFF82868E);

/// A single cover-forward sheet card: a paper-cream "cover art" face holding
/// the piece's title, with a gradient caption scrim along the bottom holding
/// the composer placeholder, participant avatars and a relative-time/owner
/// meta line.
class _SheetCoverCard extends StatefulWidget {
  const _SheetCoverCard({
    required this.piece,
    required this.state,
    required this.currentUserId,
    required this.now,
    required this.onOpenScore,
    required this.onShowQuickActions,
    super.key,
  });

  final Piece piece;
  final LibraryState state;
  final String currentUserId;
  final DateTime? now;
  final void Function(Piece piece) onOpenScore;
  final void Function(Piece piece) onShowQuickActions;

  @override
  State<_SheetCoverCard> createState() => _SheetCoverCardState();
}

class _SheetCoverCardState extends State<_SheetCoverCard> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _elevated => _hovered || _pressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final piece = widget.piece;
    final isOwned = piece.ownerId == widget.currentUserId;
    final meta = isOwned
        ? LibraryFormat.relativeTime(piece.updatedAt, now: widget.now)
        : 'from ${piece.ownerName ?? 'a friend'}';
    final avatars = _otherParticipantAvatars(piece, widget.currentUserId);
    final unread = widget.state.isUnread(piece);

    final semanticParts = <String>[
      piece.title,
      meta,
      if (avatars.isNotEmpty)
        avatars.length == 1
            ? '${avatars.length} collaborator'
            : '${avatars.length} collaborators',
      if (unread) 'unread activity',
    ];

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: semanticParts.join(', '),
      // The tap/long-press live on the inner InkWell, which `excludeSemantics`
      // hides from assistive tech — so surface them on this node too, or the
      // card reads as a button that does nothing when activated and the
      // long-press quick actions are unreachable.
      onTap: () => widget.onOpenScore(piece),
      onLongPress: () => widget.onShowQuickActions(piece),
      child: AnimatedScale(
        scale: _elevated ? 1.02 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: _elevated ? 0.26 : 0.12,
                ),
                blurRadius: _elevated ? 18 : 8,
                offset: Offset(0, _elevated ? 8 : 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadii.cardRadius,
            child: AspectRatio(
              aspectRatio: 4 / 5.2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.onOpenScore(piece),
                  onLongPress: () => widget.onShowQuickActions(piece),
                  onSecondaryTapDown: (_) => widget.onShowQuickActions(piece),
                  onHighlightChanged: (value) =>
                      setState(() => _pressed = value),
                  onHover: (value) => setState(() => _hovered = value),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _SheetCoverArt(title: piece.title, scheme: scheme),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _SheetCoverCaption(
                          scheme: scheme,
                          title: piece.title,
                          meta: meta,
                          avatars: avatars,
                          unread: unread,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The paper-cream "cover art" face: the piece's real title, centered in a
/// serif display face, over decorative faux staff lines. No composer here —
/// see `_SheetCoverCaption` for the (placeholder) composer line.
class _SheetCoverArt extends StatelessWidget {
  const _SheetCoverArt({required this.title, required this.scheme});

  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _paperColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: ExcludeSemantics(child: _StaffLines()),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: scheme.shadow,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffLines extends StatelessWidget {
  const _StaffLines();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_StaffCluster(), _StaffCluster()],
      ),
    );
  }
}

class _StaffCluster extends StatelessWidget {
  const _StaffCluster();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(height: 5),
          const _StaffLine(),
        ],
      ],
    );
  }
}

class _StaffLine extends StatelessWidget {
  const _StaffLine();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: _staffLineColor);
  }
}

/// The bottom gradient scrim holding the title, the composer placeholder,
/// the participant avatars and the meta/unread indicator.
class _SheetCoverCaption extends StatelessWidget {
  const _SheetCoverCaption({
    required this.scheme,
    required this.title,
    required this.meta,
    required this.avatars,
    required this.unread,
  });

  final ColorScheme scheme;
  final String title;
  final String meta;
  final List<AvatarStackPerson> avatars;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            scheme.surface.withValues(alpha: 0.96),
            scheme.surface.withValues(alpha: 0.55),
            scheme.surface.withValues(alpha: 0),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            ExcludeSemantics(
              child: Text(
                'Sheet music',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                if (avatars.isNotEmpty) ...[
                  AvatarStack(people: avatars, radius: 11, overlap: 8),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.circle, size: 8, color: scheme.error),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
