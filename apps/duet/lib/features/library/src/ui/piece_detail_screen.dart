import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/library/src/bloc/piece_detail_cubit.dart';
import 'package:duet/features/library/src/ui/library_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Entry widget for Piece Detail: provides [PieceDetailCubit] (loading
/// [pieceId]) and renders [PieceDetailScreen].
class PieceDetailPage extends StatelessWidget {
  /// Creates a [PieceDetailPage].
  const PieceDetailPage({
    required this.pieceRepository,
    required this.currentUserId,
    required this.pieceId,
    required this.onOpenScore,
    this.onInvitePiece,
    this.onOpenCollaborators,
    this.onExportBundle,
    this.onImportBundle,
    super.key,
  });

  /// Where the piece is loaded from and mutated.
  final PieceRepository pieceRepository;

  /// The signed-in user's id.
  final String currentUserId;

  /// The piece to load.
  final String pieceId;

  /// Called when the user taps "Open score", to navigate to `feature_score`'s
  /// `ScoreViewerScreen` — a callback for the same cross-package reason as
  /// `LibraryPage.onOpenScore`.
  final void Function(Piece piece) onOpenScore;

  /// Called when the owner taps "Invite a friend", to open `feature_pairing`'s
  /// invite sheet. A callback for the same cross-package reason as
  /// [onOpenScore]. `null` hides the action entirely.
  final void Function(Piece piece)? onInvitePiece;

  /// Called when the user taps "Collaborators", to navigate to
  /// `feature_pairing`'s Collaborators screen. A callback for the same
  /// cross-package reason as [onOpenScore]. `null` hides the tile entirely.
  final void Function(Piece piece)? onOpenCollaborators;

  /// Called when the user taps "Export review bundle" in Offline sharing, to
  /// export this piece's annotations as a `.duet` bundle and share it — the
  /// airplane-mode escape hatch (M4.2). A callback for the same cross-package
  /// reason as [onOpenScore] (`review_sync` is app-glue's dependency). `null`
  /// hides the action.
  final void Function(Piece piece)? onExportBundle;

  /// Called when the user taps "Import review bundle" in Offline sharing, to
  /// pick and merge a `.duet` bundle a collaborator sent. See [onExportBundle].
  /// `null` hides the action.
  final VoidCallback? onImportBundle;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PieceDetailCubit>(
      create: (_) {
        final cubit = PieceDetailCubit(
          pieceRepository: pieceRepository,
          currentUserId: currentUserId,
        );
        unawaited(cubit.load(pieceId));
        return cubit;
      },
      child: PieceDetailScreen(
        onOpenScore: onOpenScore,
        onInvitePiece: onInvitePiece,
        onOpenCollaborators: onOpenCollaborators,
        onExportBundle: onExportBundle,
        onImportBundle: onImportBundle,
      ),
    );
  }
}

/// The Piece Detail body: metadata, collaborators, "Open score", and an
/// ownership-appropriate overflow menu. Reads [PieceDetailCubit] from context
/// (provided by [PieceDetailPage]).
class PieceDetailScreen extends StatelessWidget {
  /// Creates a [PieceDetailScreen].
  const PieceDetailScreen({
    required this.onOpenScore,
    this.onInvitePiece,
    this.onOpenCollaborators,
    this.onExportBundle,
    this.onImportBundle,
    super.key,
  });

  /// See [PieceDetailPage.onOpenScore].
  final void Function(Piece piece) onOpenScore;

  /// See [PieceDetailPage.onInvitePiece].
  final void Function(Piece piece)? onInvitePiece;

  /// See [PieceDetailPage.onOpenCollaborators].
  final void Function(Piece piece)? onOpenCollaborators;

  /// See [PieceDetailPage.onExportBundle].
  final void Function(Piece piece)? onExportBundle;

  /// See [PieceDetailPage.onImportBundle].
  final VoidCallback? onImportBundle;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PieceDetailCubit, PieceDetailState>(
      listenWhen: (previous, current) =>
          (current.deleted && !previous.deleted) ||
          (current.left && !previous.left) ||
          (current.error != null && current.error != previous.error),
      listener: (context, state) {
        if (state.deleted || state.left) {
          Navigator.of(context).pop();
          return;
        }
        final error = state.error;
        if (error != null) AppSnackbar.error(context, error);
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(state.piece?.title ?? 'Sheet'),
            actions: [
              if (state.status == PieceDetailStatus.ready)
                const _OverflowMenu(),
            ],
          ),
          body: switch (state.status) {
            PieceDetailStatus.loading => const LoadingView(),
            PieceDetailStatus.failure => ErrorRetryView(
              title: "Couldn't load this sheet",
              message: state.error,
              onRetry: () {
                final pieceId = state.pieceId;
                if (pieceId != null) {
                  unawaited(context.read<PieceDetailCubit>().load(pieceId));
                }
              },
            ),
            PieceDetailStatus.ready => _ReadyBody(
              state: state,
              onOpenScore: onOpenScore,
              onInvitePiece: onInvitePiece,
              onOpenCollaborators: onOpenCollaborators,
              onExportBundle: onExportBundle,
              onImportBundle: onImportBundle,
            ),
          },
        );
      },
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({
    required this.state,
    required this.onOpenScore,
    this.onInvitePiece,
    this.onOpenCollaborators,
    this.onExportBundle,
    this.onImportBundle,
  });

  final PieceDetailState state;
  final void Function(Piece piece) onOpenScore;
  final void Function(Piece piece)? onInvitePiece;
  final void Function(Piece piece)? onOpenCollaborators;
  final void Function(Piece piece)? onExportBundle;
  final VoidCallback? onImportBundle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final piece = state.piece!;
    final isOwner = state.currentRole == PieceRole.owner;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(piece.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Imported ${LibraryFormat.relativeTime(piece.createdAt)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // A collaborator sees who shared the sheet with them; there is
          // always exactly one owner.
          if (!isOwner)
            PersonTile(
              initials: LibraryFormat.initialsFor(piece.ownerId),
              color: Color(LibraryFormat.colorValueFor(piece.ownerId)),
              name: piece.ownerName ?? 'Owner',
              subtitle: 'Shared this sheet with you',
            ),
          if (onOpenCollaborators != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppListTile(
              leading: piece.collaborators.isEmpty
                  ? const Icon(Icons.group_outlined)
                  : AvatarStack(
                      people: [
                        for (final collaborator in piece.collaborators)
                          (
                            initials: LibraryFormat.initialsFor(
                              collaborator.uid,
                            ),
                            color: Color(
                              LibraryFormat.colorValueFor(collaborator.uid),
                            ),
                          ),
                      ],
                    ),
              title: Text('Collaborators (${piece.collaboratorCount})'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpenCollaborators!(piece),
            ),
          ],
          // Only the owner can invite others onto their sheet.
          if (isOwner && onInvitePiece != null) ...[
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: 'Invite a friend',
              onPressed: () => onInvitePiece!(piece),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Open score',
            onPressed: () => onOpenScore(piece),
          ),
          if (onExportBundle != null || onImportBundle != null)
            _OfflineSharingSection(
              piece: piece,
              onExportBundle: onExportBundle,
              onImportBundle: onImportBundle,
            ),
        ],
      ),
    );
  }
}

/// The airplane-mode escape hatch (M4.2): export this piece's annotations as a
/// `.duet` bundle to share by hand, or import one a collaborator sent — kept
/// off the primary reader UI (live sync is the default there) but reachable
/// here when there's no connection.
class _OfflineSharingSection extends StatelessWidget {
  const _OfflineSharingSection({
    required this.piece,
    this.onExportBundle,
    this.onImportBundle,
  });

  final Piece piece;
  final void Function(Piece piece)? onExportBundle;
  final VoidCallback? onImportBundle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onExport = onExportBundle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text('Offline sharing', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'No connection? Export a review bundle to share by hand, or import '
          'one a collaborator sent you.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (onExport != null) ...[
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Export review bundle',
            onPressed: () => onExport(piece),
          ),
        ],
        if (onImportBundle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Import review bundle',
            onPressed: onImportBundle,
          ),
        ],
      ],
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PieceDetailCubit>();
    return BlocBuilder<PieceDetailCubit, PieceDetailState>(
      builder: (context, state) {
        final isOwner = state.currentRole == PieceRole.owner;
        return PopupMenuButton<String>(
          onSelected: (value) => unawaited(
            _onSelected(context, cubit, state, value),
          ),
          itemBuilder: (context) => [
            if (isOwner)
              const PopupMenuItem<String>(
                value: 'rename',
                child: Text('Rename'),
              ),
            if (isOwner)
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete'),
              ),
            if (!isOwner)
              const PopupMenuItem<String>(value: 'leave', child: Text('Leave')),
          ],
        );
      },
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    PieceDetailCubit cubit,
    PieceDetailState state,
    String value,
  ) async {
    switch (value) {
      case 'rename':
        final title = await _promptForTitle(context, state.piece!.title);
        if (title != null && title.isNotEmpty) await cubit.rename(title);
      case 'delete':
        final confirmed = await confirmDialog(
          context,
          title: 'Delete this sheet?',
          message: 'This permanently deletes the sheet for everyone on it.',
          confirmLabel: 'Delete',
          isDestructive: true,
        );
        if (confirmed) await cubit.delete();
      case 'leave':
        final confirmed = await confirmDialog(
          context,
          title: 'Leave this sheet?',
          message: "You'll lose access until invited again.",
          confirmLabel: 'Leave',
          isDestructive: true,
        );
        if (confirmed) await cubit.leave();
    }
  }

  Future<String?> _promptForTitle(BuildContext context, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename sheet'),
        content: AppTextField(controller: controller, label: 'Title'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Save',
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
          ),
        ],
      ),
    );
  }
}
