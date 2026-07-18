import 'dart:async';

import 'package:audio/audio.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/current_user_name.dart';
import 'package:duet/data/recording_path_builder.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:duet/features/score/score.dart';
import 'package:duet/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:review_prompter/review_prompter.dart';

/// Resolves [pieceId] against the [PieceRepository] before mounting the
/// reader (M5.5): the `/score/:pieceId` route is now a deep-link/push
/// destination, so any id can arrive here — an unknown or denied one lands
/// back on `/home` with a snackbar (G4) instead of stranding the user on a
/// dead score screen. In-app navigation (library taps) passes ids that are
/// known to exist, so the extra resolve is a cheap repository hit there.
class DuetScoreRouteGuard extends StatefulWidget {
  /// Creates a [DuetScoreRouteGuard] for [pieceId].
  const DuetScoreRouteGuard({required this.pieceId, super.key});

  /// The piece to resolve and open.
  final String pieceId;

  @override
  State<DuetScoreRouteGuard> createState() => _DuetScoreRouteGuardState();
}

class _DuetScoreRouteGuardState extends State<DuetScoreRouteGuard> {
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    final result = await getIt<PieceRepository>().getPiece(widget.pieceId);
    if (!mounted) return;
    switch (result) {
      case Success<Piece>():
        setState(() => _resolved = true);
      case ResultFailure<Piece>():
        // Shown once `/home`'s library scaffold mounts — the messenger
        // queues it across the navigation.
        AppSnackbar.error(context, 'That sheet is no longer available');
        context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) => _resolved
      ? DuetScorePage(pieceId: widget.pieceId)
      : const Scaffold(body: LoadingView());
}

/// Hosts `feature_score`'s Score Viewer for [pieceId]: builds the
/// [ScoreBloc] from the shared repositories, and wires the app-glue
/// `feature_score` deliberately doesn't own — the "nudge a collaborator"
/// action (`NudgeService`, M4.2; bundle share/import moved to Piece Detail),
/// and the live sync badge, which subscribes to a [PieceSyncMonitor] and maps
/// its [PieceSyncState] onto the reader's presentational [ScoreSyncStatus]
/// (the feature stays Firebase-blind; G3).
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
  // re-`watch`ed per build) so the single `StreamBuilder` below subscribes to
  // a stable stream exactly once — `watch` is single-subscription and one
  // `DuetScorePage` is alive per open piece.
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
          onNudgeRequested: _nudge,
          onNoteSaved: _logNoteSaved,
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

  /// Signals the M7.6 review prompter that the user's core action — saving
  /// an audio note — just happened. Resolved lazily/async (see
  /// `injection.dart`: construction touches the SharedPreferences platform
  /// channel) and fire-and-forget: review bookkeeping must never block or
  /// fail the save flow it piggybacks on.
  void _logNoteSaved() {
    unawaited(
      getIt.getAsync<ReviewPrompter>().then(
        (prompter) => prompter.logCoreActionCompleted(),
      ),
    );
  }

  /// Pings the piece's other participants that the current user added notes —
  /// the reader's "Nudge" affordance (Layers panel + save-note snackbar). The
  /// send is server-authoritative under Firebase (`sendNudge` callable) and
  /// in-memory otherwise; either way the app glue owns it so the feature stays
  /// Firebase-blind (G3). `fromName` seeds the mock path's copy; the callable
  /// resolves it from the caller's token instead.
  Future<void> _nudge() async {
    final result = await getIt<NudgeService>().nudge(
      pieceId: widget.pieceId,
      fromName: getIt<CurrentUserName>().call() ?? 'Someone',
    );
    if (!mounted) return;
    switch (result) {
      case Success<void>():
        AppSnackbar.success(context, 'Nudge sent');
      case ResultFailure<void>(:final error):
        AppSnackbar.error(context, "Couldn't nudge: $error");
    }
  }
}
