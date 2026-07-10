import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:feature_score/src/bloc/score_bloc.dart';
import 'package:feature_score/src/ui/widgets/sync_status_badge.dart';
import 'package:flutter/material.dart';

/// The reader's 64px top bar: back, title/subtitle, a page-nav pill (view
/// mode only), a mode status badge, collaborator avatars (view only), an
/// optional Layers button, and the overflow menu.
///
/// Purely presentational — every action is a callback, so this can be pumped
/// standalone in tests without a `ScoreBloc` in scope.
class ReaderTopBar extends StatelessWidget {
  /// Creates a [ReaderTopBar].
  const ReaderTopBar({
    required this.title,
    required this.mode,
    required this.currentPage,
    required this.pageCount,
    required this.syncStatus,
    required this.cleanWorkspace,
    required this.onBack,
    this.collaborators = const [],
    this.collaboratorNames = const [],
    this.ownInkColor,
    this.onPreviousPage,
    this.onNextPage,
    this.onOpenLayers,
    this.onShare,
    this.onImport,
    this.onPracticePage,
    this.compact = false,
    super.key,
  });

  /// The piece's title.
  final String title;

  /// The current interaction mode, driving both the subtitle and the status
  /// badge.
  final ScoreMode mode;

  /// The zero-based page currently shown.
  final int currentPage;

  /// The piece's total page count.
  final int pageCount;

  /// The review-sync status, shown when neither drawing nor clean-workspace
  /// takes priority (see the class doc's badge-priority rule).
  final ScoreSyncStatus syncStatus;

  /// Whether the clean-workspace mask is on.
  final bool cleanWorkspace;

  /// The non-owner participants, for the collaborator avatar stack (view
  /// mode only).
  final List<AvatarStackPerson> collaborators;

  /// Display names for the collaborators, used to build the "Duet with X
  /// & Y" subtitle. Parallel to (but independent of) [collaborators] so this
  /// widget never needs a full participant model.
  final List<String> collaboratorNames;

  /// The signed-in participant's own ink colour, shown as the "Drawing in
  /// your layer" badge's dot. Falls back to `colorScheme.primary` when
  /// unset.
  final Color? ownInkColor;

  /// Called when the back button is tapped.
  final VoidCallback onBack;

  /// Called when the page-nav pill's previous-page chevron is tapped.
  /// `null` disables it (e.g. already on the first page).
  final VoidCallback? onPreviousPage;

  /// Called when the page-nav pill's next-page chevron is tapped. `null`
  /// disables it (e.g. already on the last page).
  final VoidCallback? onNextPage;

  /// Called when the Layers button is tapped. `null` hides the button
  /// entirely (used when the Layers panel is docked inline instead).
  final VoidCallback? onOpenLayers;

  /// Called when "Share my annotations" is selected. `null` hides the item.
  final Future<void> Function()? onShare;

  /// Called when "Import review bundle" is selected. `null` hides the item.
  final Future<void> Function()? onImport;

  /// Called when "Practice this page" is selected. `null` hides the item.
  final VoidCallback? onPracticePage;

  /// Whether to render the compact (narrow-width) layout: drops the page-nav
  /// pill and collaborator avatars so the fixed trailing cluster can't overrun
  /// a phone-width bar. The status badge is kept but rendered `Flexible` so it
  /// shrinks rather than overflows.
  final bool compact;

  /// Composer is a placeholder literal — there is no composer-metadata field
  /// on `Piece` yet (mirrors `feature_library`'s `LibraryFormat`/gallery
  /// cards, which show the same literal rather than a fabricated composer).
  static const String _composerPlaceholder = 'Sheet music';

  String get _subtitle => switch (mode) {
    ScoreMode.view =>
      collaboratorNames.isEmpty
          ? _composerPlaceholder
          : '$_composerPlaceholder · Duet with '
                '${_joinNames(collaboratorNames)}',
    ScoreMode.draw || ScoreMode.regionSelect =>
      '$_composerPlaceholder · Page ${currentPage + 1} of $pageCount',
  };

  static String _joinNames(List<String> names) {
    if (names.length == 1) return names.single;
    return '${names.sublist(0, names.length - 1).join(', ')} & ${names.last}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  _subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (mode == ScoreMode.view && !compact) ...[
            const SizedBox(width: AppSpacing.sm),
            _PageNavPill(
              currentPage: currentPage,
              pageCount: pageCount,
              onPreviousPage: onPreviousPage,
              onNextPage: onNextPage,
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          // Flexible so a wide badge (e.g. "Drawing in your layer") shrinks
          // and ellipsizes instead of overflowing a narrow bar.
          Flexible(child: _statusBadge(scheme)),
          if (mode == ScoreMode.view &&
              collaborators.isNotEmpty &&
              !compact) ...[
            const SizedBox(width: AppSpacing.sm),
            AvatarStack(people: collaborators),
          ],
          if (onOpenLayers != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Semantics(
              button: true,
              label: 'Layers',
              child: SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: const Icon(Icons.layers_outlined),
                  onPressed: onOpenLayers,
                ),
              ),
            ),
          ],
          _OverflowMenu(
            onPracticePage: onPracticePage,
            onShare: onShare,
            onImport: onImport,
          ),
        ],
      ),
    );
  }

  /// Draw mode always wins; then clean-workspace; else the sync badge —
  /// never more than one status shown at once.
  Widget _statusBadge(ColorScheme scheme) {
    if (mode == ScoreMode.draw) {
      return StatusPill(
        label: 'Drawing in your layer',
        dotColor: ownInkColor ?? scheme.primary,
      );
    }
    if (cleanWorkspace) {
      return const StatusPill(
        label: 'Clean workspace',
        icon: Icons.layers_clear_outlined,
      );
    }
    return SyncStatusBadge(status: syncStatus);
  }
}

class _PageNavPill extends StatelessWidget {
  const _PageNavPill({
    required this.currentPage,
    required this.pageCount,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final int currentPage;
  final int pageCount;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Previous page',
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: onPreviousPage,
              ),
            ),
          ),
          Text(
            'Page ${currentPage + 1} of $pageCount',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          Semantics(
            button: true,
            label: 'Next page',
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNextPage,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({this.onPracticePage, this.onShare, this.onImport});

  final VoidCallback? onPracticePage;
  final Future<void> Function()? onShare;
  final Future<void> Function()? onImport;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) => [
        if (onPracticePage != null)
          PopupMenuItem<void>(
            onTap: onPracticePage,
            child: const Text('Practice this page'),
          ),
        if (onShare != null)
          PopupMenuItem<void>(
            onTap: () => unawaited(onShare!()),
            child: const Text('Share my annotations'),
          ),
        if (onImport != null)
          PopupMenuItem<void>(
            onTap: () => unawaited(onImport!()),
            child: const Text('Import review bundle'),
          ),
      ],
    );
  }
}
