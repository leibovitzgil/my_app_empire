import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:feature_library/src/bloc/library_bloc.dart';
import 'package:feature_library/src/data/pdf_file_picker.dart';
import 'package:feature_library/src/ui/import_piece_screen.dart';
import 'package:feature_library/src/ui/library_format.dart';
import 'package:feature_library/src/ui/piece_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';

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

/// Entry widget for the library feature: provides [LibraryBloc] and renders
/// [LibraryHomeScreen]. Apps wire this in with one line, supplying the
/// concrete repositories/services and the cross-feature navigation callbacks
/// this package can't own directly (see [onOpenScore]/[onInvitePiece]).
class LibraryPage extends StatelessWidget {
  /// Creates a [LibraryPage].
  const LibraryPage({
    required this.pieceRepository,
    required this.renderService,
    required this.currentUserId,
    required this.onOpenScore,
    this.onInvitePiece,
    this.onOpenCollaborators,
    this.onOpenSettings,
    this.filePicker,
    this.currentUserName,
    super.key,
  });

  /// The shared piece data source.
  final PieceRepository pieceRepository;

  /// Used by the import flow to validate a picked PDF opens cleanly.
  final PdfRenderService renderService;

  /// The signed-in user's id.
  final String currentUserId;

  /// Called to navigate to `feature_score`'s `ScoreViewerScreen` for the
  /// given piece. A callback rather than a direct dependency: `feature_library`
  /// and `feature_score` are siblings that must not depend on each other, so
  /// the app-glue layer owns the actual route.
  final void Function(Piece piece) onOpenScore;

  /// Called when the user wants to invite a friend to a sheet they own (from
  /// Piece Detail). A callback for the same reason as [onOpenScore]: the
  /// invite sheet lives in `feature_pairing`, a sibling package. `null` hides
  /// the action entirely (e.g. an app that hasn't wired pairing yet).
  final void Function(Piece piece)? onInvitePiece;

  /// Called when the user taps a piece's "Collaborators (N)" tile in Piece
  /// Detail, to navigate to `feature_pairing`'s Collaborators screen. A
  /// callback for the same reason as [onOpenScore]/[onInvitePiece]. `null`
  /// hides the tile entirely (see `PieceDetailScreen.onOpenCollaborators`).
  final void Function(Piece piece)? onOpenCollaborators;

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
        currentUserId: currentUserId,
        onOpenScore: onOpenScore,
        onInvitePiece: onInvitePiece,
        onOpenCollaborators: onOpenCollaborators,
        onOpenSettings: onOpenSettings,
        filePicker: filePicker,
        currentUserName: currentUserName,
      ),
    );
  }
}

/// The unified Home / Sheet Library body: two tabs ("My sheets" / "Shared with
/// me") over the same piece stream. Reads [LibraryBloc] from context (provided
/// by [LibraryPage]).
class LibraryHomeScreen extends StatelessWidget {
  /// Creates a [LibraryHomeScreen].
  const LibraryHomeScreen({
    required this.pieceRepository,
    required this.renderService,
    required this.currentUserId,
    required this.onOpenScore,
    this.onInvitePiece,
    this.onOpenCollaborators,
    this.onOpenSettings,
    this.filePicker,
    this.currentUserName,
    super.key,
  });

  /// The shared piece data source.
  final PieceRepository pieceRepository;

  /// Used by the import flow to validate a picked PDF opens cleanly.
  final PdfRenderService renderService;

  /// The signed-in user's id.
  final String currentUserId;

  /// See [LibraryPage.onOpenScore].
  final void Function(Piece piece) onOpenScore;

  /// See [LibraryPage.onInvitePiece].
  final void Function(Piece piece)? onInvitePiece;

  /// See [LibraryPage.onOpenCollaborators].
  final void Function(Piece piece)? onOpenCollaborators;

  /// See [LibraryPage.onOpenSettings].
  final VoidCallback? onOpenSettings;

  /// See [LibraryPage.filePicker].
  final PdfFilePicker? filePicker;

  /// See [LibraryPage.currentUserName].
  final String? currentUserName;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, state) {
        final ready = state.status == LibraryStatus.ready;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Duet'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Import a sheet',
                  onPressed: () => unawaited(_openImportFlow(context)),
                ),
                if (onOpenSettings != null)
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Settings',
                    onPressed: onOpenSettings,
                  ),
              ],
              bottom: ready
                  ? const TabBar(
                      tabs: [
                        Tab(text: 'My sheets'),
                        Tab(text: 'Shared with me'),
                      ],
                    )
                  : null,
            ),
            body: switch (state.status) {
              LibraryStatus.loading => const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: SkeletonList(),
              ),
              LibraryStatus.failure => ErrorRetryView(
                title: "Couldn't load your library",
                message: state.error,
                onRetry: () =>
                    context.read<LibraryBloc>().add(const LibraryStarted()),
              ),
              LibraryStatus.ready => TabBarView(
                children: [
                  _MySheetsTab(
                    pieces: state.myPieces,
                    state: state,
                    currentUserId: currentUserId,
                    onOpenScore: (piece) => _openScore(context, piece),
                    onOpenDetail: (piece) => _openDetail(context, piece),
                    onImport: () => unawaited(_openImportFlow(context)),
                  ),
                  _SharedTab(
                    pieces: state.sharedWithMe,
                    state: state,
                    currentUserId: currentUserId,
                    onOpenScore: (piece) => _openScore(context, piece),
                    onOpenDetail: (piece) => _openDetail(context, piece),
                  ),
                ],
              ),
            },
          ),
        );
      },
    );
  }

  void _markViewed(BuildContext context, Piece piece) =>
      context.read<LibraryBloc>().add(PieceViewed(piece.id));

  void _openScore(BuildContext context, Piece piece) {
    _markViewed(context, piece);
    onOpenScore(piece);
  }

  void _openDetail(BuildContext context, Piece piece) {
    _markViewed(context, piece);
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PieceDetailPage(
            pieceRepository: pieceRepository,
            currentUserId: currentUserId,
            pieceId: piece.id,
            onOpenScore: onOpenScore,
            onInvitePiece: onInvitePiece,
            onOpenCollaborators: onOpenCollaborators,
          ),
        ),
      ),
    );
  }

  Future<void> _openImportFlow(BuildContext context) async {
    final piece = await Navigator.of(context).push<Piece>(
      MaterialPageRoute<Piece>(
        builder: (_) => ImportPiecePage(
          pieceRepository: pieceRepository,
          renderService: renderService,
          filePicker: filePicker,
          ownerName: currentUserName,
        ),
      ),
    );
    if (piece != null) onOpenScore(piece);
  }
}

/// A single sheet row, shared by both tabs. Tapping the row opens the Score
/// Viewer; tapping the trailing info button opens Piece Detail.
class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.piece,
    required this.subtitle,
    required this.unread,
    required this.currentUserId,
    required this.onOpenScore,
    required this.onOpenDetail,
  });

  final Piece piece;
  final String subtitle;
  final bool unread;
  final String currentUserId;
  final void Function(Piece piece) onOpenScore;
  final void Function(Piece piece) onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final avatars = _otherParticipantAvatars(piece, currentUserId);
    return AppListTile(
      leading: avatars.isEmpty ? null : AvatarStack(people: avatars),
      title: Text(piece.title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unread)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Semantics(
                label: 'Unread activity',
                child: Icon(
                  Icons.circle,
                  size: 8,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '${piece.title} details',
            onPressed: () => onOpenDetail(piece),
          ),
        ],
      ),
      onTap: () => onOpenScore(piece),
    );
  }
}

class _MySheetsTab extends StatelessWidget {
  const _MySheetsTab({
    required this.pieces,
    required this.state,
    required this.currentUserId,
    required this.onOpenScore,
    required this.onOpenDetail,
    required this.onImport,
  });

  final List<Piece> pieces;
  final LibraryState state;
  final String currentUserId;
  final void Function(Piece piece) onOpenScore;
  final void Function(Piece piece) onOpenDetail;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    if (pieces.isEmpty) {
      return EmptyStateView(
        icon: Icons.library_music_outlined,
        title: 'Your library is empty',
        message:
            'Import a PDF to add your first sheet, or open an invite '
            'link from a friend to see what they’ve shared.',
        messagePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        action: PrimaryButton(label: 'Import a sheet', onPressed: onImport),
      );
    }
    return ListView(
      children: [
        for (final piece in pieces)
          _SheetTile(
            piece: piece,
            subtitle: 'Updated ${LibraryFormat.relativeTime(piece.updatedAt)}',
            unread: state.isUnread(piece),
            currentUserId: currentUserId,
            onOpenScore: onOpenScore,
            onOpenDetail: onOpenDetail,
          ),
      ],
    );
  }
}

class _SharedTab extends StatelessWidget {
  const _SharedTab({
    required this.pieces,
    required this.state,
    required this.currentUserId,
    required this.onOpenScore,
    required this.onOpenDetail,
  });

  final List<Piece> pieces;
  final LibraryState state;
  final String currentUserId;
  final void Function(Piece piece) onOpenScore;
  final void Function(Piece piece) onOpenDetail;

  @override
  Widget build(BuildContext context) {
    if (pieces.isEmpty) {
      return const EmptyStateView(
        icon: Icons.inbox_outlined,
        title: 'Nothing shared yet',
        message: 'Sheets your friends share with you will appear here.',
        messagePadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      );
    }
    return ListView(
      children: [
        for (final piece in pieces)
          _SheetTile(
            piece: piece,
            subtitle:
                'Shared by ${piece.ownerName ?? 'Owner'} · '
                '${LibraryFormat.relativeTime(piece.updatedAt)}',
            unread: state.isUnread(piece),
            currentUserId: currentUserId,
            onOpenScore: onOpenScore,
            onOpenDetail: onOpenDetail,
          ),
      ],
    );
  }
}
