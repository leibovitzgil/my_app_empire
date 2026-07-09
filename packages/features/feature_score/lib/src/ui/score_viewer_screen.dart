import 'dart:async';

import 'package:audio/audio.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_score/src/bloc/audio_playback_cubit.dart';
import 'package:feature_score/src/bloc/record_audio_cubit.dart';
import 'package:feature_score/src/bloc/score_bloc.dart';
import 'package:feature_score/src/ui/practice_view.dart';
import 'package:feature_score/src/ui/widgets/audio_pin_marker.dart';
import 'package:feature_score/src/ui/widgets/draw_toolbar.dart';
import 'package:feature_score/src/ui/widgets/fractional_region_align.dart';
import 'package:feature_score/src/ui/widgets/ink_overlay.dart';
import 'package:feature_score/src/ui/widgets/ink_palette.dart';
import 'package:feature_score/src/ui/widgets/layer_toggle_bar.dart';
import 'package:feature_score/src/ui/widgets/region_selector.dart';
import 'package:feature_score/src/ui/widgets/score_page_canvas.dart';
import 'package:feature_score/src/ui/widgets/sync_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';

/// The Score Viewer: the app's core screen. Wired to [ScoreBloc] (read from
/// context) for the heavy-lift annotation/state logic, and owns its own
/// [RecordAudioCubit]/[AudioPlaybackCubit] for the screen-scoped
/// recording/playback flows.
class ScoreViewerScreen extends StatefulWidget {
  /// Creates a [ScoreViewerScreen].
  const ScoreViewerScreen({
    required this.renderService,
    required this.recorderService,
    required this.playerService,
    required this.recordingPathBuilder,
    required this.audioAssetStore,
    this.syncStatus = ScoreSyncStatus.notSynced,
    this.onShareRequested,
    this.onImportRequested,
    super.key,
  });

  /// The PDF render service, opened on the current piece by this screen.
  final PdfRenderService renderService;

  /// The audio recorder service, wrapped by this screen's [RecordAudioCubit].
  final AudioRecorderService recorderService;

  /// The audio player service, wrapped by this screen's [AudioPlaybackCubit].
  final AudioPlayerService playerService;

  /// Produces a fresh on-device output path for a new recording. Injected
  /// rather than resolved here so this package doesn't need to depend on
  /// `path_provider` directly; the app-glue layer supplies this.
  final String Function() recordingPathBuilder;

  /// Resolves a durable id for a just-recorded file (see
  /// `_saveAudioNote`) and resolves a saved [AudioNote.audioAssetId] back to
  /// a playable path (see `_ReadyBody._playNote`) — an audio note's
  /// `audioAssetId` must never be treated as a raw filesystem path.
  final AudioAssetStore audioAssetStore;

  /// The review-sync status to show in the app bar's badge. This package
  /// deliberately doesn't own a live sync source (that's `review_sync`,
  /// app-glue's dependency, not this package's) — callers pass whatever they
  /// track, defaulting to [ScoreSyncStatus.notSynced].
  final ScoreSyncStatus syncStatus;

  /// Invoked when "Share my annotations" is selected from the overflow menu,
  /// if provided; `null` hides the action. A callback rather than a direct
  /// `review_sync` dependency, for the same cross-package reason as
  /// `feature_library`'s `onOpenScore`/`onInvitePiece`.
  final Future<void> Function()? onShareRequested;

  /// Invoked when "Import review bundle" is selected from the overflow menu,
  /// if provided; `null` hides the action. See [onShareRequested].
  final Future<void> Function()? onImportRequested;

  @override
  State<ScoreViewerScreen> createState() => _ScoreViewerScreenState();
}

class _ScoreViewerScreenState extends State<ScoreViewerScreen> {
  late final RecordAudioCubit _recordCubit;
  late final AudioPlaybackCubit _playbackCubit;
  String? _openedPdfPath;

  @override
  void initState() {
    super.initState();
    _recordCubit = RecordAudioCubit(recorder: widget.recorderService);
    _playbackCubit = AudioPlaybackCubit(player: widget.playerService);
  }

  @override
  void dispose() {
    unawaited(_recordCubit.close());
    unawaited(_playbackCubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<RecordAudioCubit>.value(value: _recordCubit),
        BlocProvider<AudioPlaybackCubit>.value(value: _playbackCubit),
      ],
      child: BlocConsumer<ScoreBloc, ScoreState>(
        listenWhen: (previous, current) =>
            previous.activeRegion != current.activeRegion ||
            previous.regionIntent != current.regionIntent,
        listener: _onRegionSelectionChanged,
        builder: (context, state) {
          final path = state.piece?.basePdfPath;
          if (path != null && path != _openedPdfPath) {
            _openedPdfPath = path;
            unawaited(widget.renderService.open(path));
          }
          return Scaffold(
            appBar: _buildAppBar(context, state),
            body: switch (state.status) {
              ScoreStatus.loading => const LoadingView(
                label: 'Loading score…',
              ),
              ScoreStatus.failure => ErrorRetryView(
                title: "Couldn't load this sheet",
                message: state.error,
                onRetry: () {
                  final pieceId = state.pieceId;
                  if (pieceId != null) {
                    context.read<ScoreBloc>().add(ScoreOpened(pieceId));
                  }
                },
              ),
              ScoreStatus.ready => _ReadyBody(
                state: state,
                renderService: widget.renderService,
                audioAssetStore: widget.audioAssetStore,
              ),
            },
            floatingActionButton: state.status == ScoreStatus.ready
                ? _ModeButtons(state: state)
                : null,
          );
        },
      ),
    );
  }

  void _onRegionSelectionChanged(BuildContext context, ScoreState state) {
    final region = state.activeRegion;
    final intent = state.regionIntent;
    if (region == null || intent == null) return;
    switch (intent) {
      case RegionIntent.recordAudio:
        unawaited(_showRecordSheet(context, region, state));
      case RegionIntent.practice:
        _openPracticeView(context, region, state);
    }
  }

  Future<void> _showRecordSheet(
    BuildContext context,
    Region region,
    ScoreState state,
  ) async {
    final scoreBloc = context.read<ScoreBloc>();
    await AppBottomSheet.show<void>(
      context,
      title: 'Record audio note',
      isDismissible: false,
      builder: (sheetContext) => BlocProvider<RecordAudioCubit>.value(
        value: _recordCubit,
        child: _RecordAudioSheetBody(
          outputPathBuilder: widget.recordingPathBuilder,
          onSaved: (path, elapsed) {
            unawaited(_saveAudioNote(scoreBloc, state, region, path, elapsed));
          },
        ),
      ),
    );
    scoreBloc.add(const RegionSelectionCleared());
  }

  /// Resolves the just-recorded file at [recordedPath] to a durable asset id
  /// via [AudioAssetStore.put] before constructing the [AudioNote] — an
  /// audio note's `audioAssetId` must never be the raw recording path (it
  /// needs to keep resolving after the recording's temp file is gone, and
  /// after an export/import round-trip through `review_sync`, which reads
  /// and writes assets by id).
  Future<void> _saveAudioNote(
    ScoreBloc scoreBloc,
    ScoreState state,
    Region region,
    String recordedPath,
    Duration elapsed,
  ) async {
    final putResult = await widget.audioAssetStore.put(recordedPath);
    final assetId = switch (putResult) {
      Success<String>(:final value) => value,
      // Falls back to the raw path so the note isn't silently dropped; it
      // just won't survive past this recording's temp file the way a
      // properly-stored asset would.
      ResultFailure<String>() => recordedPath,
    };
    final note = AudioNote(
      id: 'note_${DateTime.now().microsecondsSinceEpoch}',
      authorId: state.currentUserId,
      audioAssetId: assetId,
      pageIndex: region.pageIndex,
      durationMs: elapsed.inMilliseconds,
      region: region,
      createdAt: DateTime.now(),
    );
    scoreBloc.add(AudioNoteSaved(note, recordedPath));
  }

  void _openPracticeView(
    BuildContext context,
    Region region,
    ScoreState state,
  ) {
    final scoreBloc = context.read<ScoreBloc>();
    unawaited(
      Navigator.of(context)
          .push<void>(
            MaterialPageRoute<void>(
              builder: (_) => PracticeView(
                region: region,
                renderService: widget.renderService,
                layers: [
                  for (final layer in state.layers)
                    if (layer.visible) layer,
                ],
              ),
            ),
          )
          .then((_) => scoreBloc.add(const RegionSelectionCleared())),
    );
  }

  AppBar _buildAppBar(BuildContext context, ScoreState state) {
    final bloc = context.read<ScoreBloc>();
    return AppBar(
      title: Text(state.piece?.title ?? 'Score'),
      actions: [
        SyncStatusBadge(status: widget.syncStatus),
        const SizedBox(width: AppSpacing.sm),
        Semantics(
          button: true,
          label: state.cleanWorkspace
              ? 'Clean workspace on. Double tap to show annotations again.'
              : 'Clean workspace off. Double tap to hide all annotations.',
          child: SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              isSelected: state.cleanWorkspace,
              icon: const Icon(Icons.layers_outlined),
              selectedIcon: const Icon(Icons.layers_clear_outlined),
              onPressed: () => bloc.add(const CleanWorkspaceToggled()),
            ),
          ),
        ),
        PopupMenuButton<void>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem<void>(
              onTap: () => bloc
                ..add(const RegionSelectStarted(RegionIntent.practice))
                ..add(
                  RegionSelectCompleted(
                    Region(
                      pageIndex: state.currentPage,
                      left: 0,
                      top: 0,
                      width: 1,
                      height: 1,
                    ),
                  ),
                ),
              child: const Text('Practice this page'),
            ),
            if (widget.onShareRequested != null)
              PopupMenuItem<void>(
                onTap: () => unawaited(widget.onShareRequested!()),
                child: const Text('Share my annotations'),
              ),
            if (widget.onImportRequested != null)
              PopupMenuItem<void>(
                onTap: () => unawaited(widget.onImportRequested!()),
                child: const Text('Import review bundle'),
              ),
          ],
        ),
      ],
    );
  }
}

class _ModeButtons extends StatelessWidget {
  const _ModeButtons({required this.state});

  final ScoreState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ScoreBloc>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: state.mode == ScoreMode.draw
              ? 'Drawing mode on. Double tap to turn off.'
              : 'Drawing mode off. Double tap to draw.',
          child: FloatingActionButton(
            heroTag: 'score_draw_mode',
            backgroundColor: state.mode == ScoreMode.draw
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            onPressed: () => bloc.add(
              ModeChanged(
                state.mode == ScoreMode.draw ? ScoreMode.view : ScoreMode.draw,
              ),
            ),
            child: const Icon(Icons.edit_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          button: true,
          label: state.mode == ScoreMode.regionSelect
              ? 'Region select mode on. Double tap to turn off.'
              : 'Region select mode off. Double tap to select a passage.',
          child: FloatingActionButton(
            heroTag: 'score_region_select_mode',
            backgroundColor: state.mode == ScoreMode.regionSelect
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            onPressed: () => bloc.add(
              ModeChanged(
                state.mode == ScoreMode.regionSelect
                    ? ScoreMode.view
                    : ScoreMode.regionSelect,
              ),
            ),
            child: const Icon(Icons.crop_free),
          ),
        ),
      ],
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({
    required this.state,
    required this.renderService,
    required this.audioAssetStore,
  });

  final ScoreState state;
  final PdfRenderService renderService;
  final AudioAssetStore audioAssetStore;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ScoreBloc>();
    final pageIndex = state.currentPage;
    return Column(
      children: [
        LayerToggleBar(
          layers: state.layers,
          audioPinsVisible: state.audioPinsVisible,
          onInkToggle: (ownerId) => bloc.add(InkLayerToggled(ownerId)),
          onAudioToggle: () => bloc.add(const AudioPinsToggled()),
        ),
        Expanded(
          child: Stack(
            children: [
              ScorePageCanvas(
                renderService: renderService,
                pageIndex: pageIndex,
                overlays: [
                  for (final layer in state.layers)
                    if (state.effectiveInkVisible(layer))
                      InkOverlay(
                        strokes: layer.strokes,
                        pageIndex: pageIndex,
                        color: inkColorForId(layer.colorId),
                      ),
                  if (state.mode == ScoreMode.draw)
                    _DrawGestureLayer(pageIndex: pageIndex),
                  if (state.mode == ScoreMode.regionSelect)
                    RegionSelector(
                      pageIndex: pageIndex,
                      onRegionPreview: (region) =>
                          bloc.add(RegionDragUpdated(region)),
                      onRegionChosen: (region, intent) => bloc
                        ..add(RegionSelectStarted(intent))
                        ..add(RegionSelectCompleted(region)),
                    ),
                  if (state.effectiveAudioPinsVisible)
                    for (final note in state.notes.where(
                      (n) => n.pageIndex == pageIndex,
                    ))
                      FractionalRegionAlign(
                        region: note.region,
                        child:
                            BlocBuilder<AudioPlaybackCubit, AudioPlaybackState>(
                              builder: (context, playback) {
                                return AudioPinMarker(
                                  note: note,
                                  currentUserId: state.currentUserId,
                                  isPlaying: playback.isPlaying(note.id),
                                  progress: _progressValue(playback, note.id),
                                  onTap: () =>
                                      _onPinTap(context, note, playback),
                                  onDelete: () => context.read<ScoreBloc>().add(
                                    AudioNoteDeleteRequested(note.id),
                                  ),
                                );
                              },
                            ),
                      ),
                ],
              ),
              Positioned(
                right: AppSpacing.md,
                top: AppSpacing.md,
                child: Chip(label: Text('Page ${pageIndex + 1}')),
              ),
            ],
          ),
        ),
        if (state.mode == ScoreMode.draw)
          DrawToolbar(
            penColor: inkColorForId(state.ownLayer?.colorId ?? 'p0'),
            eraserActive: state.eraserActive,
            canUndo: state.undoStack.isNotEmpty,
            onEraserToggled: () => bloc.add(const EraserToggled()),
            onUndo: () => bloc.add(const UndoRequested()),
          ),
      ],
    );
  }

  double? _progressValue(AudioPlaybackState playback, String noteId) {
    if (!playback.isPlaying(noteId)) return null;
    final progress = playback.progress;
    if (progress == null || progress.duration == Duration.zero) return null;
    return progress.position.inMilliseconds / progress.duration.inMilliseconds;
  }

  void _onPinTap(
    BuildContext context,
    AudioNote note,
    AudioPlaybackState playback,
  ) {
    final playbackCubit = context.read<AudioPlaybackCubit>();
    if (playback.isPlaying(note.id)) {
      unawaited(playbackCubit.stop());
    } else {
      unawaited(_playNote(playbackCubit, note));
    }
  }

  /// Resolves [AudioNote.audioAssetId] to a playable path via
  /// [AudioAssetStore.pathFor] before starting playback — the id is never
  /// itself a path (see [_ScoreViewerScreenState._saveAudioNote]).
  Future<void> _playNote(
    AudioPlaybackCubit playbackCubit,
    AudioNote note,
  ) async {
    final pathResult = await audioAssetStore.pathFor(note.audioAssetId);
    final path = switch (pathResult) {
      Success<String>(:final value) => value,
      // Falls back to treating the id as a path directly — covers a note
      // saved before this asset-store wiring existed.
      ResultFailure<String>() => note.audioAssetId,
    };
    await playbackCubit.play(note.id, path);
  }
}

/// Captures a freehand drag as a series of fractional [InkPoint]s and
/// dispatches [StrokeCompleted] on release; in eraser mode, taps hit-test
/// against the current user's own strokes and dispatch [StrokeErased].
class _DrawGestureLayer extends StatefulWidget {
  const _DrawGestureLayer({required this.pageIndex});

  final int pageIndex;

  @override
  State<_DrawGestureLayer> createState() => _DrawGestureLayerState();
}

class _DrawGestureLayerState extends State<_DrawGestureLayer> {
  final List<Offset> _livePoints = [];

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ScoreBloc>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            if (bloc.state.eraserActive) return;
            setState(() {
              _livePoints
                ..clear()
                ..add(details.localPosition);
            });
          },
          onPanUpdate: (details) {
            if (bloc.state.eraserActive) return;
            setState(() => _livePoints.add(details.localPosition));
          },
          onPanEnd: (_) {
            if (bloc.state.eraserActive ||
                _livePoints.length < 2 ||
                size.width <= 0 ||
                size.height <= 0) {
              setState(_livePoints.clear);
              return;
            }
            final points = _livePoints
                .map(
                  (p) => InkPoint(x: p.dx / size.width, y: p.dy / size.height),
                )
                .toList();
            bloc.add(StrokeCompleted(points));
            setState(_livePoints.clear);
          },
          onTapUp: (details) {
            if (!bloc.state.eraserActive ||
                size.width <= 0 ||
                size.height <= 0) {
              return;
            }
            final own = bloc.state.ownLayer?.strokes ?? const <InkStroke>[];
            final hit = _hitStroke(
              own,
              widget.pageIndex,
              details.localPosition,
              size,
            );
            if (hit != null) bloc.add(StrokeErased(hit.id));
          },
          child: CustomPaint(
            painter: _LiveStrokePainter(
              points: _livePoints,
              colorId: bloc.state.ownLayer?.colorId ?? 'p0',
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  InkStroke? _hitStroke(
    List<InkStroke> strokes,
    int pageIndex,
    Offset tapLocal,
    Size size,
  ) {
    const threshold = 20.0;
    InkStroke? best;
    var bestDistance = double.infinity;
    for (final stroke in strokes) {
      if (stroke.pageIndex != pageIndex) continue;
      for (final point in stroke.points) {
        final offset = Offset(point.x * size.width, point.y * size.height);
        final distance = (offset - tapLocal).distance;
        if (distance < threshold && distance < bestDistance) {
          bestDistance = distance;
          best = stroke;
        }
      }
    }
    return best;
  }
}

class _LiveStrokePainter extends CustomPainter {
  _LiveStrokePainter({required this.points, required this.colorId});

  final List<Offset> points;
  final String colorId;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = inkColorForId(colorId)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiveStrokePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.colorId != colorId;
}

/// The contents of the "Record audio note" bottom sheet, wired to
/// [RecordAudioCubit].
class _RecordAudioSheetBody extends StatelessWidget {
  const _RecordAudioSheetBody({
    required this.outputPathBuilder,
    required this.onSaved,
  });

  final String Function() outputPathBuilder;
  final void Function(String path, Duration elapsed) onSaved;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordAudioCubit, RecordAudioState>(
      builder: (context, state) {
        final cubit = context.read<RecordAudioCubit>();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(state),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.status == RecordAudioStatus.error)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  state.error ?? 'Something went wrong.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            _buildActions(context, cubit, state),
          ],
        );
      },
    );
  }

  String _label(RecordAudioState state) {
    final seconds = state.elapsed.inSeconds;
    return switch (state.status) {
      RecordAudioStatus.idle => 'Ready to record.',
      RecordAudioStatus.recording => 'Recording… ${seconds}s',
      RecordAudioStatus.reviewing => 'Recorded ${seconds}s. Keep it?',
      RecordAudioStatus.error => "Couldn't record.",
    };
  }

  Widget _buildActions(
    BuildContext context,
    RecordAudioCubit cubit,
    RecordAudioState state,
  ) {
    switch (state.status) {
      case RecordAudioStatus.idle:
      case RecordAudioStatus.error:
        return Semantics(
          button: true,
          label: 'Start recording',
          child: SizedBox(
            width: 48,
            height: 48,
            child: IconButton.filled(
              icon: const Icon(Icons.mic),
              onPressed: () => cubit.start(outputPathBuilder()),
            ),
          ),
        );
      case RecordAudioStatus.recording:
        return Semantics(
          button: true,
          label: 'Stop recording',
          child: SizedBox(
            width: 48,
            height: 48,
            child: IconButton.filled(
              icon: const Icon(Icons.stop),
              onPressed: cubit.stop,
            ),
          ),
        );
      case RecordAudioStatus.reviewing:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SecondaryButton(
              label: 'Discard',
              onPressed: () {
                cubit.discard();
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(width: AppSpacing.md),
            PrimaryButton(
              label: 'Save',
              onPressed: () {
                final path = state.path;
                if (path != null) onSaved(path, state.elapsed);
                cubit.save();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
    }
  }
}
