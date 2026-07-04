import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:feature_library/src/bloc/library_bloc.dart';
import 'package:feature_library/src/data/pdf_file_picker.dart';
import 'package:feature_library/src/domain/duet_permissions.dart';
import 'package:feature_library/src/ui/import_piece_screen.dart';
import 'package:feature_library/src/ui/library_format.dart';
import 'package:feature_library/src/ui/piece_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';
import 'package:user_roles/user_roles.dart';

/// Entry widget for the library feature: provides [LibraryBloc] and renders
/// [LibraryHomeScreen]. Apps wire this in with one line, supplying the
/// concrete repositories/services and the two cross-feature navigation
/// callbacks this package can't own directly (see [onOpenScore]/
/// [onInvitePiece] docs).
class LibraryPage extends StatelessWidget {
  /// Creates a [LibraryPage].
  const LibraryPage({
    required this.pieceRepository,
    required this.renderService,
    required this.userRoleRepository,
    required this.currentUserId,
    required this.currentRole,
    required this.onOpenScore,
    this.onInvitePiece,
    this.filePicker,
    this.currentUserName,
    super.key,
  });

  /// The shared piece data source.
  final PieceRepository pieceRepository;

  /// Used by the import flow to validate a picked PDF opens cleanly.
  final PdfRenderService renderService;

  /// Gates the teacher-only "Import piece"/"Invite student" actions.
  final UserRoleRepository userRoleRepository;

  /// The signed-in participant's id.
  final String currentUserId;

  /// Whether the signed-in participant is a teacher or a student.
  final PieceRole currentRole;

  /// Called to navigate to `feature_score`'s `ScoreViewerScreen` for the
  /// given piece. A callback rather than a direct dependency: `feature_library`
  /// and `feature_score` are siblings that must not depend on each other, so
  /// the app-glue layer owns the actual route.
  final void Function(Piece piece) onOpenScore;

  /// Called when a teacher wants to invite a student for a given piece. A
  /// callback for the same reason as [onOpenScore]: the invite sheet lives in
  /// `feature_pairing`, a sibling package. `null` hides the action entirely
  /// (e.g. an app that hasn't wired pairing yet).
  final void Function(Piece piece)? onInvitePiece;

  /// Picks a PDF for the import flow. Defaults to [pickPdfFile]; override in
  /// tests to avoid the platform channel.
  final PdfFilePicker? filePicker;

  /// The signed-in teacher's display name, if known — sourced from auth
  /// identity and attached to any piece created via the import flow (see
  /// `ImportPieceBloc.teacherName`). `null` falls back to an
  /// initials-from-id placeholder wherever this piece's teacher is shown.
  final String? currentUserName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LibraryBloc>(
      create: (_) => LibraryBloc(
        pieceRepository: pieceRepository,
        currentUserId: currentUserId,
        currentRole: currentRole,
      )..add(const LibraryStarted()),
      child: LibraryHomeScreen(
        pieceRepository: pieceRepository,
        renderService: renderService,
        userRoleRepository: userRoleRepository,
        currentUserId: currentUserId,
        onOpenScore: onOpenScore,
        onInvitePiece: onInvitePiece,
        filePicker: filePicker,
        currentUserName: currentUserName,
      ),
    );
  }
}

/// The role-aware Home / Piece List body. Reads [LibraryBloc] from context
/// (provided by [LibraryPage]).
class LibraryHomeScreen extends StatelessWidget {
  /// Creates a [LibraryHomeScreen].
  const LibraryHomeScreen({
    required this.pieceRepository,
    required this.renderService,
    required this.userRoleRepository,
    required this.currentUserId,
    required this.onOpenScore,
    this.onInvitePiece,
    this.filePicker,
    this.currentUserName,
    super.key,
  });

  /// The shared piece data source.
  final PieceRepository pieceRepository;

  /// Used by the import flow to validate a picked PDF opens cleanly.
  final PdfRenderService renderService;

  /// Gates the teacher-only "Import piece"/"Invite student" actions.
  final UserRoleRepository userRoleRepository;

  /// The signed-in participant's id.
  final String currentUserId;

  /// See [LibraryPage.onOpenScore].
  final void Function(Piece piece) onOpenScore;

  /// See [LibraryPage.onInvitePiece].
  final void Function(Piece piece)? onInvitePiece;

  /// See [LibraryPage.filePicker].
  final PdfFilePicker? filePicker;

  /// See [LibraryPage.currentUserName].
  final String? currentUserName;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, state) {
        final isTeacher = state.currentRole == PieceRole.teacher;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Duet'),
            actions: isTeacher
                ? [
                    PermissionGate(
                      repository: userRoleRepository,
                      permission: DuetPermissions.inviteStudent,
                      child: IconButton(
                        icon: const Icon(Icons.person_add_alt),
                        tooltip: 'Invite student',
                        onPressed: () =>
                            unawaited(_onInviteStudent(context, state)),
                      ),
                    ),
                    PermissionGate(
                      repository: userRoleRepository,
                      permission: DuetPermissions.importPiece,
                      child: IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Import piece',
                        onPressed: () => unawaited(_openImportFlow(context)),
                      ),
                    ),
                  ]
                : null,
          ),
          body: switch (state.status) {
            LibraryStatus.loading => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SkeletonList(),
            ),
            LibraryStatus.failure => ErrorRetryView(
              title: "Couldn't load your pieces",
              message: state.error,
              onRetry: () =>
                  context.read<LibraryBloc>().add(const LibraryStarted()),
            ),
            LibraryStatus.ready =>
              isTeacher
                  ? _TeacherBody(
                      state: state,
                      onOpenPiece: (piece) => _openDetail(context, piece),
                      onInvitePiece: onInvitePiece == null
                          ? null
                          : (piece) => onInvitePiece!(piece),
                    )
                  : _StudentBody(
                      state: state,
                      onOpenPiece: (piece) => _openDetail(context, piece),
                    ),
          },
        );
      },
    );
  }

  void _openDetail(BuildContext context, Piece piece) {
    context.read<LibraryBloc>().add(PieceViewed(piece.id));
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PieceDetailPage(
            pieceRepository: pieceRepository,
            currentUserId: currentUserId,
            pieceId: piece.id,
            onOpenScore: onOpenScore,
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
          teacherName: currentUserName,
        ),
      ),
    );
    if (piece != null) onOpenScore(piece);
  }

  Future<void> _onInviteStudent(
    BuildContext context,
    LibraryState state,
  ) async {
    final onInvite = onInvitePiece;
    if (onInvite == null) return;
    final unpaired = state.unpairedPieces;
    if (unpaired.isEmpty) {
      AppSnackbar.info(context, 'Import a piece first to invite a student');
      return;
    }
    if (unpaired.length == 1) {
      onInvite(unpaired.single);
      return;
    }
    final chosen = await showModalBottomSheet<Piece>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('Invite a student for which piece?'),
            ),
            for (final piece in unpaired)
              AppListTile(
                title: Text(piece.title),
                onTap: () => Navigator.of(sheetContext).pop(piece),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) onInvite(chosen);
  }
}

class _TeacherBody extends StatelessWidget {
  const _TeacherBody({
    required this.state,
    required this.onOpenPiece,
    required this.onInvitePiece,
  });

  final LibraryState state;
  final void Function(Piece piece) onOpenPiece;
  final void Function(Piece piece)? onInvitePiece;

  @override
  Widget build(BuildContext context) {
    final grouped = state.piecesByStudent;
    if (grouped.isEmpty) {
      return const EmptyStateView(
        icon: Icons.library_music_outlined,
        title: 'No pieces yet',
        message: 'Import a piece to get started',
      );
    }
    final studentIds = grouped.keys.whereType<String>().toList()..sort();
    final unpaired = grouped[null] ?? const <Piece>[];
    return ListView(
      children: [
        for (final studentId in studentIds)
          _StudentGroup(
            studentId: studentId,
            pieces: grouped[studentId]!,
            state: state,
            onOpenPiece: onOpenPiece,
          ),
        if (unpaired.isNotEmpty)
          _UnpairedGroup(
            pieces: unpaired,
            onOpenPiece: onOpenPiece,
            onInvitePiece: onInvitePiece,
          ),
      ],
    );
  }
}

class _StudentGroup extends StatefulWidget {
  const _StudentGroup({
    required this.studentId,
    required this.pieces,
    required this.state,
    required this.onOpenPiece,
  });

  final String studentId;
  final List<Piece> pieces;
  final LibraryState state;
  final void Function(Piece piece) onOpenPiece;

  @override
  State<_StudentGroup> createState() => _StudentGroupState();
}

class _StudentGroupState extends State<_StudentGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasUnread = widget.pieces.any(widget.state.isUnread);
    // All of a student's pieces should carry the same `studentName` (it's
    // set once, at pairing time), but fall back across the group in case an
    // older/imported piece predates the field on just one of them.
    final studentName = widget.pieces
        .map((p) => p.studentName)
        .firstWhere((name) => name != null, orElse: () => null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PersonTile(
          initials: LibraryFormat.initialsFor(widget.studentId),
          color: Color(LibraryFormat.colorValueFor(widget.studentId)),
          name:
              studentName ??
              'Student ${LibraryFormat.initialsFor(widget.studentId)}',
          subtitle:
              '${widget.pieces.length} shared '
              '${widget.pieces.length == 1 ? 'piece' : 'pieces'}',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasUnread)
                const Padding(
                  padding: EdgeInsets.only(right: AppSpacing.xs),
                  child: Icon(Icons.circle, size: 8, color: Colors.red),
                ),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          for (final piece in widget.pieces)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg),
              child: AppListTile(
                title: Text(piece.title),
                subtitle: Text(
                  'Last activity: '
                  '${LibraryFormat.relativeTime(piece.updatedAt)}',
                ),
                trailing: widget.state.isUnread(piece)
                    ? const Icon(Icons.circle, size: 8, color: Colors.red)
                    : null,
                onTap: () => widget.onOpenPiece(piece),
              ),
            ),
      ],
    );
  }
}

class _UnpairedGroup extends StatelessWidget {
  const _UnpairedGroup({
    required this.pieces,
    required this.onOpenPiece,
    required this.onInvitePiece,
  });

  final List<Piece> pieces;
  final void Function(Piece piece) onOpenPiece;
  final void Function(Piece piece)? onInvitePiece;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            'Awaiting a student',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final piece in pieces)
          AppListTile(
            title: Text(piece.title),
            subtitle: Text(
              'Imported ${LibraryFormat.relativeTime(piece.createdAt)}',
            ),
            trailing: onInvitePiece == null
                ? null
                : TextButton(
                    onPressed: () => onInvitePiece!(piece),
                    child: const Text('Invite'),
                  ),
            onTap: () => onOpenPiece(piece),
          ),
      ],
    );
  }
}

class _StudentBody extends StatelessWidget {
  const _StudentBody({required this.state, required this.onOpenPiece});

  final LibraryState state;
  final void Function(Piece piece) onOpenPiece;

  @override
  Widget build(BuildContext context) {
    final pieces = state.sharedWithMe;
    if (pieces.isEmpty) {
      return const EmptyStateView(
        icon: Icons.library_music_outlined,
        title: 'No pieces yet',
        message: 'Ask your teacher for an invite link to get started',
      );
    }
    return ListView(
      children: [
        for (final piece in pieces)
          AppListTile(
            title: Text(piece.title),
            subtitle: Text(
              piece.teacherName ??
                  'Teacher ${LibraryFormat.initialsFor(piece.teacherId)}',
            ),
            trailing: state.isUnread(piece)
                ? const Icon(Icons.circle, size: 8, color: Colors.red)
                : null,
            onTap: () => onOpenPiece(piece),
          ),
      ],
    );
  }
}
