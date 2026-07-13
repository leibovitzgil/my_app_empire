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
/// [ScoreBloc] from the shared repositories, and wires the app-glue
/// `feature_score` deliberately doesn't own — the review-sync bundle
/// (share/import) actions, and the live sync badge, which subscribes to a
/// [PieceSyncMonitor] and maps its [PieceSyncState] onto the reader's
/// presentational [ScoreSyncStatus] (the feature stays Firebase-blind; G3).
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

  // The reader's live sync signal (M4.1): a `PieceSyncMonitor` folds real
  // persistence state (Firestore pending writes + the audio upload-queue depth
  // + server reachability) into a `PieceSyncState`. Held once here (not
  // re-`watch`ed per build) so the subscription is stable across rebuilds.
  late final Stream<PieceSyncState> _syncStates = getIt<PieceSyncMonitor>()
      .watch(widget.pieceId);

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
      child: StreamBuilder<PieceSyncState>(
        stream: _syncStates,
        builder: (context, snapshot) => ScoreViewerScreen(
          renderService: getIt<PdfRenderService>(),
          recorderService: getIt<AudioRecorderService>(),
          playerService: getIt<AudioPlayerService>(),
          recordingPathBuilder: recordingPathBuilder.call,
          audioAssetStore: getIt<AudioAssetStore>(),
          syncStatus: _syncStatusFor(snapshot.data),
          onShareRequested: _share,
          onImportRequested: _import,
        ),
      ),
    );
  }

  /// Maps the monitor's [PieceSyncState] onto the reader's presentational
  /// [ScoreSyncStatus]. `offline` maps to the `notSynced` badge (the
  /// `cloud_off_outlined` pill) — copy intent for that state:
  /// "Offline — changes saved on this iPad" (the work is safe on-device and
  /// syncs on reconnect). A `null` (before the monitor's first emission) reads
  /// as syncing while the piece's state is still being established.
  ScoreSyncStatus _syncStatusFor(PieceSyncState? state) => switch (state) {
    PieceSyncState.synced => ScoreSyncStatus.synced,
    PieceSyncState.syncing => ScoreSyncStatus.syncing,
    PieceSyncState.offline => ScoreSyncStatus.notSynced,
    null => ScoreSyncStatus.syncing,
  };

  Future<void> _share() async {
    final exportResult = await getIt<ReviewSyncService>().exportBundle(
      widget.pieceId,
    );
    if (!mounted) return;
    switch (exportResult) {
      case Success<ExportedBundle>(:final value):
        final shareResult = await getIt<ReviewSyncService>().share(value);
        if (!mounted) return;
        // The badge is monitor-driven now, so a successful share needs no
        // status plumbing here — only surface a failure.
        if (shareResult case ResultFailure<void>(:final error)) {
          AppSnackbar.error(context, "Couldn't share: $error");
        }
      case ResultFailure<ExportedBundle>(:final error):
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
    final result = await getIt<ReviewSyncService>().importBundle(path);
    if (!mounted) return;
    switch (result) {
      case Success<ReviewBundleSummary>(:final value):
        AppSnackbar.success(
          context,
          'Imported ${value.strokeCount} strokes, '
          '${value.audioNoteCount} notes',
        );
      case ResultFailure<ReviewBundleSummary>(:final error):
        AppSnackbar.error(context, "Couldn't import: $error");
    }
  }
}
