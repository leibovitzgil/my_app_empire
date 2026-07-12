import 'dart:async';

import 'package:audio/audio.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/recording_path_builder.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/score/score.dart';
import 'package:duet/injection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

/// Hosts `feature_score`'s Score Viewer for [pieceId]: builds the
/// [ScoreBloc] from the shared repositories, and wires the two bits of
/// app-glue `feature_score` deliberately doesn't own — manual review-sync
/// (share/import) actions, since sync in this MVP is explicit rather than
/// automatic, and a session-local sync-status badge reflecting them.
class DuetScorePage extends StatefulWidget {
  /// Creates a [DuetScorePage] for [pieceId].
  const DuetScorePage({required this.pieceId, super.key});

  /// The piece to open.
  final String pieceId;

  @override
  State<DuetScorePage> createState() => _DuetScorePageState();
}

class _DuetScorePageState extends State<DuetScorePage> {
  late final ScoreBloc _scoreBloc = ScoreBloc(
    pieceRepository: getIt<PieceRepository>(),
    annotationRepository: getIt<AnnotationRepository>(),
    currentUserId: getIt<CurrentUser>().call(),
    // Resolves the base PDF to a readable local path (cache/download) before
    // the reader opens it — offline reads hit the cache (M3.4).
    pdfBinaryCache: getIt<PdfBinaryCache>(),
  )..add(ScoreOpened(widget.pieceId));

  // Session-local only: this MVP's sync is manual (explicit share/import),
  // so there's no persisted "last synced at" to restore on reopen — every
  // fresh visit to the Score Viewer starts `notSynced` until the user
  // shares or imports again. See the phase report for the fuller judgment
  // call this reflects.
  ScoreSyncStatus _syncStatus = ScoreSyncStatus.notSynced;

  // Resolved lazily/async (see `injection.dart`) rather than at app boot, so
  // it's loaded here, once, the first time this screen actually needs it.
  RecordingPathBuilder? _recordingPathBuilder;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecordingPathBuilder());
  }

  Future<void> _loadRecordingPathBuilder() async {
    final builder = await getIt.getAsync<RecordingPathBuilder>();
    if (mounted) setState(() => _recordingPathBuilder = builder);
  }

  @override
  void dispose() {
    unawaited(_scoreBloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordingPathBuilder = _recordingPathBuilder;
    if (recordingPathBuilder == null) {
      return const Scaffold(body: LoadingView());
    }
    return BlocProvider<ScoreBloc>.value(
      value: _scoreBloc,
      child: ScoreViewerScreen(
        renderService: getIt<PdfRenderService>(),
        recorderService: getIt<AudioRecorderService>(),
        playerService: getIt<AudioPlayerService>(),
        recordingPathBuilder: recordingPathBuilder.call,
        audioAssetStore: getIt<AudioAssetStore>(),
        syncStatus: _syncStatus,
        onShareRequested: _share,
        onImportRequested: _import,
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _syncStatus = ScoreSyncStatus.syncing);
    final exportResult = await getIt<ReviewSyncService>().exportBundle(
      widget.pieceId,
    );
    switch (exportResult) {
      case Success<ExportedBundle>(:final value):
        final shareResult = await getIt<ReviewSyncService>().share(value);
        if (!mounted) return;
        switch (shareResult) {
          case Success<void>():
            setState(() => _syncStatus = ScoreSyncStatus.synced);
          case ResultFailure<void>(:final error):
            setState(() => _syncStatus = ScoreSyncStatus.notSynced);
            AppSnackbar.error(context, "Couldn't share: $error");
        }
      case ResultFailure<ExportedBundle>(:final error):
        if (!mounted) return;
        setState(() => _syncStatus = ScoreSyncStatus.notSynced);
        AppSnackbar.error(context, "Couldn't export: $error");
    }
  }

  Future<void> _import() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['duet'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;
    if (!mounted) return;
    setState(() => _syncStatus = ScoreSyncStatus.syncing);
    final result = await getIt<ReviewSyncService>().importBundle(path);
    if (!mounted) return;
    switch (result) {
      case Success<ReviewBundleSummary>(:final value):
        setState(() => _syncStatus = ScoreSyncStatus.synced);
        AppSnackbar.success(
          context,
          'Imported ${value.strokeCount} strokes, '
          '${value.audioNoteCount} notes',
        );
      case ResultFailure<ReviewBundleSummary>(:final error):
        setState(() => _syncStatus = ScoreSyncStatus.notSynced);
        AppSnackbar.error(context, "Couldn't import: $error");
    }
  }
}
