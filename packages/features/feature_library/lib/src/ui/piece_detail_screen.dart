import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:feature_library/src/bloc/piece_detail_cubit.dart';
import 'package:feature_library/src/ui/library_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pieces/pieces.dart';

/// Entry widget for Piece Detail: provides [PieceDetailCubit] (loading
/// [pieceId]) and renders [PieceDetailScreen].
class PieceDetailPage extends StatelessWidget {
  /// Creates a [PieceDetailPage].
  const PieceDetailPage({
    required this.pieceRepository,
    required this.currentUserId,
    required this.pieceId,
    required this.onOpenScore,
    this.onOpenCollaborators,
    super.key,
  });

  /// Where the piece is loaded from and mutated.
  final PieceRepository pieceRepository;

  /// The signed-in participant's id.
  final String currentUserId;

  /// The piece to load.
  final String pieceId;

  /// Called when the user taps "Open score", to navigate to `feature_score`'s
  /// `ScoreViewerScreen` — a callback for the same cross-package reason as
  /// `LibraryPage.onOpenScore`.
  final void Function(Piece piece) onOpenScore;

  /// Called when the user taps "Collaborators", to navigate to
  /// `feature_pairing`'s Collaborators screen. A callback for the same
  /// cross-package reason as [onOpenScore]: `feature_library` and
  /// `feature_pairing` are siblings that must not depend on each other.
  /// `null` hides the "Collaborators" tile entirely.
  final void Function(Piece piece)? onOpenCollaborators;

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
        onOpenCollaborators: onOpenCollaborators,
      ),
    );
  }
}

/// The Piece Detail body: metadata, the other party, "Open score", and a
/// role-appropriate overflow menu. Reads [PieceDetailCubit] from context
/// (provided by [PieceDetailPage]).
class PieceDetailScreen extends StatelessWidget {
  /// Creates a [PieceDetailScreen].
  const PieceDetailScreen({
    required this.onOpenScore,
    this.onOpenCollaborators,
    super.key,
  });

  /// See [PieceDetailPage.onOpenScore].
  final void Function(Piece piece) onOpenScore;

  /// See [PieceDetailPage.onOpenCollaborators].
  final void Function(Piece piece)? onOpenCollaborators;

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
            title: Text(state.piece?.title ?? 'Piece'),
            actions: [
              if (state.status == PieceDetailStatus.ready)
                const _OverflowMenu(),
            ],
          ),
          body: switch (state.status) {
            PieceDetailStatus.loading => const LoadingView(),
            PieceDetailStatus.failure => ErrorRetryView(
              title: "Couldn't load this piece",
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
              onOpenCollaborators: onOpenCollaborators,
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
    this.onOpenCollaborators,
  });

  final PieceDetailState state;
  final void Function(Piece piece) onOpenScore;
  final void Function(Piece piece)? onOpenCollaborators;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final piece = state.piece!;
    final isTeacher = state.currentRole == PieceRole.teacher;
    final otherId = isTeacher ? piece.studentId : piece.teacherId;
    final otherName = isTeacher ? piece.studentName : piece.teacherName;
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
          if (otherId != null)
            PersonTile(
              initials: LibraryFormat.initialsFor(otherId),
              color: Color(LibraryFormat.colorValueFor(otherId)),
              name:
                  otherName ??
                  (isTeacher
                      ? 'Student ${LibraryFormat.initialsFor(otherId)}'
                      : 'Teacher ${LibraryFormat.initialsFor(otherId)}'),
            )
          else
            Text(
              'No student paired yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Open score',
            onPressed: () => onOpenScore(piece),
          ),
        ],
      ),
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
        final isTeacher = state.currentRole == PieceRole.teacher;
        return PopupMenuButton<String>(
          onSelected: (value) => unawaited(
            _onSelected(context, cubit, state, value),
          ),
          itemBuilder: (context) => [
            if (isTeacher)
              const PopupMenuItem<String>(
                value: 'rename',
                child: Text('Rename'),
              ),
            if (isTeacher)
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete'),
              ),
            if (!isTeacher)
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
          title: 'Delete this piece?',
          message: 'This permanently deletes the piece for both of you.',
          confirmLabel: 'Delete',
          isDestructive: true,
        );
        if (confirmed) await cubit.delete();
      case 'leave':
        final confirmed = await confirmDialog(
          context,
          title: 'Leave this piece?',
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
        title: const Text('Rename piece'),
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
