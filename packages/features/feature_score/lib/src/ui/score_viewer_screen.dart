import 'dart:async';

import 'package:audio/audio.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_score/src/bloc/audio_playback_cubit.dart';
import 'package:feature_score/src/bloc/record_audio_cubit.dart';
import 'package:feature_score/src/bloc/score_bloc.dart';
import 'package:feature_score/src/participant_layer.dart';
import 'package:feature_score/src/ui/practice_view.dart';
import 'package:feature_score/src/ui/widgets/audio_pin_marker.dart';
import 'package:feature_score/src/ui/widgets/draw_toolbar.dart';
import 'package:feature_score/src/ui/widgets/fractional_region_align.dart';
import 'package:feature_score/src/ui/widgets/ink_overlay.dart';
import 'package:feature_score/src/ui/widgets/ink_palette.dart';
import 'package:feature_score/src/ui/widgets/layers_panel.dart';
import 'package:feature_score/src/ui/widgets/mode_segmented_control.dart';
import 'package:feature_score/src/ui/widgets/page_thumbnail_rail.dart';
import 'package:feature_score/src/ui/widgets/passage_popover.dart';
import 'package:feature_score/src/ui/widgets/playback_chip.dart';
import 'package:feature_score/src/ui/widgets/reader_top_bar.dart';
import 'package:feature_score/src/ui/widgets/region_selector.dart';
import 'package:feature_score/src/ui/widgets/score_page_canvas.dart';
import 'package:feature_score/src/ui/widgets/sync_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';

/// Below this width the rail hides and Layers moves to a bottom sheet.
const double _kMediumBreakpoint = 600;

/// At/above this width the Layers panel docks inline; below it (down to
/// [_kMediumBreakpoint]) Layers moves to an `endDrawer`.
const double _kWideBreakpoint = 840;

/// The reader's forced-dark colour scheme (the app runs `ThemeMode.system`,
/// but this screen is unconditionally dark). Computed once — `fromSeed` is a
/// pure function of its inputs, so it never needs re-deriving per rebuild.
final ColorScheme _readerDarkScheme = ColorScheme.fromSeed(
  seedColor: Colors.blue,
  brightness: Brightness.dark,
);

/// The Score Viewer: the app's core screen. Wired to [ScoreBloc] (read from
/// context) for the heavy-lift annotation/state logic, and owns its own
/// [RecordAudioCubit]/[AudioPlaybackCubit] for the screen-scoped
/// recording/playback flows.
///
/// Unconditionally dark (a forced [Theme] override), tablet-first, and
/// multi-panel — see [_ReaderCanvas] for the responsive rail/canvas/Layers
/// composition.
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
  /// a playable path (see `_ReaderCanvasState._playNote`) — an audio note's
  /// `audioAssetId` must never be treated as a raw filesystem path.
  final AudioAssetStore audioAssetStore;

  /// The review-sync status to show in the top bar's badge and the Layers
  /// panel's share prompt. This package deliberately doesn't own a live sync
  /// source (that's `review_sync`, app-glue's dependency, not this
  /// package's) — callers pass whatever they track, defaulting to
  /// [ScoreSyncStatus.notSynced].
  final ScoreSyncStatus syncStatus;

  /// Invoked when "Share" is selected (overflow menu or the Layers panel's
  /// prompt), if provided; `null` hides every share affordance. A callback
  /// rather than a direct `review_sync` dependency, for the same
  /// cross-package reason as `feature_library`'s
  /// `onOpenScore`/`onInvitePiece`.
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _openedPdfPath;

  // The PDF render service is opened asynchronously (see `_openPdf`), but the
  // piece's metadata becomes `ready` before that completes. `ScorePageCanvas`
  // calls `renderPage` on mount and requires the document to already be open,
  // so the canvas must not be shown until `open()` has actually succeeded —
  // otherwise it renders into a not-yet-open service and fails. These two
  // fields track that lifecycle so `_buildBody` can gate on it.
  bool _pdfOpen = false;
  String? _pdfOpenError;

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
          _maybeOpenPdf(state);
          return Theme(
            data: Theme.of(context).copyWith(
              brightness: Brightness.dark,
              colorScheme: _readerDarkScheme,
            ),
            child: Scaffold(
              key: _scaffoldKey,
              endDrawer: _buildEndDrawer(context, state),
              body: Column(
                children: [
                  _buildTopBar(context, state),
                  Expanded(child: _buildBody(context, state)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Opens [state]'s piece PDF exactly once per path (keyed on
  /// [_openedPdfPath], as before), now awaiting the result so a successful
  /// open can resolve the piece's real page count via [PageCountResolved].
  void _maybeOpenPdf(ScoreState state) {
    final path = state.piece?.basePdfPath;
    if (path == null || path == _openedPdfPath) return;
    _openedPdfPath = path;
    // Reset the open lifecycle for the new path. Set directly (not via
    // `setState`) — this runs inside `build`, and `_buildBody` reads these
    // fields later in the same build.
    _pdfOpen = false;
    _pdfOpenError = null;
    unawaited(_openPdf(path));
  }

  Future<void> _openPdf(String path) async {
    final result = await widget.renderService.open(path);
    // Ignore a late result for a path we've since moved off of.
    if (!mounted || path != _openedPdfPath) return;
    switch (result) {
      case Success<int>(:final value):
        setState(() {
          _pdfOpen = true;
          _pdfOpenError = null;
        });
        context.read<ScoreBloc>().add(PageCountResolved(value));
      case ResultFailure<int>(:final error):
        // Surface the failure so the reader shows why the sheet won't open
        // (e.g. a missing file) with a retry, rather than the canvas racing
        // ahead into a not-yet-open service.
        setState(() {
          _pdfOpen = false;
          _pdfOpenError = '$error';
        });
    }
  }

  /// Re-runs `open()` for the current piece PDF (used by the open-failure
  /// retry). Clears `_openedPdfPath` so `_maybeOpenPdf` treats the next build
  /// as a fresh open.
  void _retryOpenPdf() {
    setState(() {
      _openedPdfPath = null;
      _pdfOpen = false;
      _pdfOpenError = null;
    });
  }

  Widget _buildTopBar(BuildContext context, ScoreState state) {
    if (state.status != ScoreStatus.ready) {
      return _MinimalTopBar(
        title: state.piece?.title ?? 'Score',
        onBack: () => Navigator.of(context).maybePop(),
      );
    }
    final bloc = context.read<ScoreBloc>();
    final width = MediaQuery.sizeOf(context).width;
    return ReaderTopBar(
      title: state.piece?.title ?? 'Score',
      mode: state.mode,
      currentPage: state.currentPage,
      pageCount: state.pageCount,
      syncStatus: widget.syncStatus,
      cleanWorkspace: state.cleanWorkspace,
      compact: width < _kMediumBreakpoint,
      collaborators: _collaboratorAvatars(state),
      collaboratorNames: _collaboratorNames(state),
      ownInkColor: inkColorForId(state.ownLayer?.colorId ?? 'p0'),
      onBack: () => Navigator.of(context).maybePop(),
      onPreviousPage: state.isFirstPage
          ? null
          : () => bloc.add(PageChanged(state.currentPage - 1)),
      onNextPage: state.isLastPage
          ? null
          : () => bloc.add(PageChanged(state.currentPage + 1)),
      onOpenLayers: _onOpenLayers(context, state, bloc, width),
      onShare: widget.onShareRequested,
      onImport: widget.onImportRequested,
      onPracticePage: () => bloc
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
    );
  }

  /// The top bar's Layers button: hidden in draw/passage mode and whenever
  /// the panel is already docked inline (≥[_kWideBreakpoint]); opens the
  /// `endDrawer` at medium widths, or a bottom sheet below
  /// [_kMediumBreakpoint].
  VoidCallback? _onOpenLayers(
    BuildContext context,
    ScoreState state,
    ScoreBloc bloc,
    double width,
  ) {
    if (state.mode != ScoreMode.view) return null;
    if (width >= _kWideBreakpoint) return null;
    if (width >= _kMediumBreakpoint) {
      return () => _scaffoldKey.currentState?.openEndDrawer();
    }
    return () => unawaited(_showLayersBottomSheet(context, state, bloc));
  }

  Future<void> _showLayersBottomSheet(
    BuildContext context,
    ScoreState state,
    ScoreBloc bloc,
  ) {
    return AppBottomSheet.show<void>(
      context,
      builder: (sheetContext) => SizedBox(
        height: 420,
        child: _buildLayersPanel(
          bloc,
          state,
          syncStatus: widget.syncStatus,
          onShareRequested: widget.onShareRequested,
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }

  Widget? _buildEndDrawer(BuildContext context, ScoreState state) {
    if (state.status != ScoreStatus.ready || state.mode != ScoreMode.view) {
      return null;
    }
    final width = MediaQuery.sizeOf(context).width;
    if (width < _kMediumBreakpoint || width >= _kWideBreakpoint) return null;
    final bloc = context.read<ScoreBloc>();
    return Drawer(
      width: 300,
      child: _buildLayersPanel(
        bloc,
        state,
        syncStatus: widget.syncStatus,
        onShareRequested: widget.onShareRequested,
        onClose: () => _scaffoldKey.currentState?.closeEndDrawer(),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ScoreState state) {
    return switch (state.status) {
      ScoreStatus.loading => const LoadingView(label: 'Loading score…'),
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
      ScoreStatus.ready => _buildReadyBody(context, state),
    };
  }

  /// Once the piece metadata is [ScoreStatus.ready], the body still depends on
  /// the async `open()` of its PDF: show the open failure (with retry) or a
  /// loading view until the document is actually open, then the canvas.
  Widget _buildReadyBody(BuildContext context, ScoreState state) {
    if (_pdfOpenError != null) {
      return ErrorRetryView(
        title: "Couldn't open this sheet",
        message: _pdfOpenError,
        onRetry: _retryOpenPdf,
      );
    }
    if (!_pdfOpen) {
      return const LoadingView(label: 'Opening sheet…');
    }
    return _ReaderCanvas(
      state: state,
      renderService: widget.renderService,
      audioAssetStore: widget.audioAssetStore,
      syncStatus: widget.syncStatus,
      onShareRequested: widget.onShareRequested,
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
}

/// The minimal top bar shown while [ScoreStatus] isn't `ready`: back + title
/// only, no page-nav pill, status badge, or avatars — there's nothing yet to
/// show them about.
class _MinimalTopBar extends StatelessWidget {
  const _MinimalTopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds the Layers panel content shared by the docked/`endDrawer`/bottom
/// sheet hosts — only [onClose]'s behaviour differs between them.
Widget _buildLayersPanel(
  ScoreBloc bloc,
  ScoreState state, {
  required ScoreSyncStatus syncStatus,
  required Future<void> Function()? onShareRequested,
  VoidCallback? onClose,
}) {
  final pageIndex = state.currentPage;
  return LayersPanel(
    layers: state.layers,
    audioPinsVisible: state.audioPinsVisible,
    audioPinCountOnPage: state.notes
        .where((note) => note.pageIndex == pageIndex)
        .length,
    cleanWorkspace: state.cleanWorkspace,
    onInkToggle: (ownerId) => bloc.add(InkLayerToggled(ownerId)),
    onAudioToggle: () => bloc.add(const AudioPinsToggled()),
    onCleanWorkspaceToggle: () => bloc.add(const CleanWorkspaceToggled()),
    onClose: onClose,
    onShare: onShareRequested == null
        ? null
        : () => unawaited(onShareRequested()),
    annotationsShared: syncStatus == ScoreSyncStatus.synced,
  );
}

/// Word-initials from a participant's real display name, e.g. "Maya K." ->
/// "MK" — never a fabricated/placeholder identity.
String _initialsFor(String label) {
  final words = label
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final word = words.single;
    return word.substring(0, word.length < 2 ? 1 : 2).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}

// keep in sync with LibraryFormat.colorValueFor
const List<int> _kAvatarPalette = [
  0xFF8B5CF6,
  0xFFF59E0B,
  0xFF14B8A6,
  0xFFEF4444,
  0xFF6366F1,
  0xFF84CC16,
];

/// A stable avatar colour derived from a participant id — mirrors
/// `LibraryFormat.colorValueFor` (see [_kAvatarPalette]) so the same person
/// reads as the same colour in the gallery and the reader, without this
/// package depending on `feature_library`.
Color _avatarColorFor(String id) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash + unit) % _kAvatarPalette.length;
  }
  return Color(_kAvatarPalette[hash]);
}

List<AvatarStackPerson> _collaboratorAvatars(ScoreState state) {
  return [
    for (final layer in state.layers)
      if (!layer.isOwn)
        (
          initials: _initialsFor(layer.label),
          color: _avatarColorFor(layer.ownerId),
        ),
  ];
}

List<String> _collaboratorNames(ScoreState state) {
  return [
    for (final layer in state.layers)
      if (!layer.isOwn) layer.label,
  ];
}

/// `mm:ss`, matching the design's playback-chip format (no leading zero on
/// minutes).
String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// The Score Viewer's ready-state content: a responsive
/// rail/canvas/Layers-panel composition (see `build` for the three
/// breakpoints), plus the mode segmented control, draw toolbar, playback
/// chip, and passage popover that float over the page.
///
/// Stateful only for `_completedRegion` (the just-finished region-select
/// drag awaiting a Practice/Record/Cancel decision) and
/// `_layersPanelCollapsed` (the ≥[_kWideBreakpoint] docked panel's own
/// collapse toggle).
class _ReaderCanvas extends StatefulWidget {
  const _ReaderCanvas({
    required this.state,
    required this.renderService,
    required this.audioAssetStore,
    required this.syncStatus,
    required this.onShareRequested,
  });

  final ScoreState state;
  final PdfRenderService renderService;
  final AudioAssetStore audioAssetStore;
  final ScoreSyncStatus syncStatus;
  final Future<void> Function()? onShareRequested;

  @override
  State<_ReaderCanvas> createState() => _ReaderCanvasState();
}

class _ReaderCanvasState extends State<_ReaderCanvas> {
  Region? _completedRegion;
  bool _layersPanelCollapsed = false;

  @override
  void didUpdateWidget(covariant _ReaderCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Leaving passage mode any way other than resolve/cancel (e.g. tapping
    // the segmented control, which sits above the popover's tap-catcher) must
    // drop the just-dragged region — otherwise re-entering passage mode
    // resurrects a phantom popover anchored to it with no fresh drag.
    if (oldWidget.state.mode == ScoreMode.regionSelect &&
        widget.state.mode != ScoreMode.regionSelect) {
      _completedRegion = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final bloc = context.read<ScoreBloc>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showRail =
            width >= _kMediumBreakpoint && state.mode != ScoreMode.regionSelect;
        final dockPanel =
            width >= _kWideBreakpoint &&
            state.mode == ScoreMode.view &&
            !_layersPanelCollapsed;
        return Row(
          children: [
            // TODO(reader-redesign): render real PDF thumbnails once a
            // cheap per-page thumbnail render path exists; stylized cards
            // are golden-safe and match the design in the meantime (see
            // `PageThumbnailRail`'s class doc).
            if (showRail)
              PageThumbnailRail(
                pageCount: state.pageCount,
                currentPage: state.currentPage,
                presence: _pagePresence(state),
                onSelectPage: (page) => bloc.add(PageChanged(page)),
                dimmed: state.mode == ScoreMode.draw,
              ),
            Expanded(child: _canvasStack(context, state, bloc, width)),
            if (dockPanel)
              SizedBox(
                width: 300,
                child: _buildLayersPanel(
                  bloc,
                  state,
                  syncStatus: widget.syncStatus,
                  onShareRequested: widget.onShareRequested,
                  onClose: () => setState(() => _layersPanelCollapsed = true),
                ),
              ),
          ],
        );
      },
    );
  }

  List<PageInkPresence> _pagePresence(ScoreState state) {
    return [
      for (var page = 0; page < state.pageCount; page++)
        (
          hasAudio: state.notes.any((note) => note.pageIndex == page),
          inkColors: [
            for (final layer in state.layers)
              if (layer.strokes.any((stroke) => stroke.pageIndex == page))
                inkColorForId(layer.colorId),
          ].take(5).toList(),
        ),
    ];
  }

  Widget _canvasStack(
    BuildContext context,
    ScoreState state,
    ScoreBloc bloc,
    double width,
  ) {
    final pageIndex = state.currentPage;
    return Stack(
      children: [
        Center(
          child: ScorePageCanvas(
            renderService: widget.renderService,
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
                  onRegionCompleted: (region) {
                    setState(() => _completedRegion = region);
                    if (width < _kMediumBreakpoint) {
                      unawaited(
                        _showPassageBottomSheet(context, bloc, region),
                      );
                    }
                  },
                ),
              if (state.effectiveAudioPinsVisible)
                for (final note in state.notes.where(
                  (n) => n.pageIndex == pageIndex,
                ))
                  FractionalRegionAlign(
                    region: note.region,
                    child: BlocBuilder<AudioPlaybackCubit, AudioPlaybackState>(
                      builder: (context, playback) {
                        return AudioPinMarker(
                          note: note,
                          currentUserId: state.currentUserId,
                          isPlaying: playback.isPlaying(note.id),
                          progress: _progressValue(playback, note.id),
                          onTap: () => _onPinTap(context, note, playback),
                          onDelete: () => context.read<ScoreBloc>().add(
                            AudioNoteDeleteRequested(note.id),
                          ),
                        );
                      },
                    ),
                  ),
            ],
          ),
        ),
        if (state.mode == ScoreMode.regionSelect &&
            _completedRegion != null &&
            width >= _kMediumBreakpoint)
          Positioned.fill(
            child: _passagePopoverOverlay(bloc, _completedRegion!),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.lg,
          child: Center(
            child: ModeSegmentedControl(
              mode: state.mode,
              onModeSelected: (mode) => bloc.add(ModeChanged(mode)),
            ),
          ),
        ),
        if (state.mode == ScoreMode.draw)
          Positioned(
            left: 0,
            right: 0,
            bottom: 88,
            child: Center(
              child: DrawToolbar(
                penColor: inkColorForId(state.ownLayer?.colorId ?? 'p0'),
                eraserActive: state.eraserActive,
                canUndo: state.undoStack.isNotEmpty,
                onEraserToggled: () => bloc.add(const EraserToggled()),
                onUndo: () => bloc.add(const UndoRequested()),
                onDone: () => bloc.add(const ModeChanged(ScoreMode.view)),
              ),
            ),
          ),
        if (width >= _kWideBreakpoint &&
            state.mode == ScoreMode.view &&
            _layersPanelCollapsed)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Semantics(
                button: true,
                label: 'Open layers panel',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton.filled(
                    icon: const Icon(Icons.layers_outlined),
                    onPressed: () =>
                        setState(() => _layersPanelCollapsed = false),
                  ),
                ),
              ),
            ),
          ),
        _PlayingChip(state: state),
      ],
    );
  }

  /// Anchored via `FractionalRegionAlign` at [region]'s centroid, plus a
  /// page-area-scoped tap-catcher behind it so tapping outside dismisses
  /// like Cancel.
  Widget _passagePopoverOverlay(ScoreBloc bloc, Region region) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _cancelRegionSelection(bloc),
          ),
        ),
        FractionalRegionAlign(
          region: region,
          child: PassagePopover(
            onPractice: () =>
                _resolveRegionSelection(bloc, region, RegionIntent.practice),
            onRecord: () => _resolveRegionSelection(
              bloc,
              region,
              RegionIntent.recordAudio,
            ),
            onCancel: () => _cancelRegionSelection(bloc),
          ),
        ),
      ],
    );
  }

  /// The <[_kMediumBreakpoint] fallback: the existing chooser, restyled
  /// (Practice first).
  Future<void> _showPassageBottomSheet(
    BuildContext context,
    ScoreBloc bloc,
    Region region,
  ) async {
    await AppBottomSheet.show<void>(
      context,
      title: 'This passage',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Practice this passage',
            child: ListTile(
              leading: const Icon(Icons.piano),
              title: const Text('Practice this passage'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _resolveRegionSelection(bloc, region, RegionIntent.practice);
              },
            ),
          ),
          Semantics(
            button: true,
            label: 'Record an audio note for this passage',
            child: ListTile(
              leading: const Icon(Icons.mic_none_outlined),
              title: const Text('Record an audio note'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _resolveRegionSelection(
                  bloc,
                  region,
                  RegionIntent.recordAudio,
                );
              },
            ),
          ),
          Semantics(
            button: true,
            label: 'Cancel region selection',
            child: ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        ],
      ),
    );
    // An explicit Practice/Record tap already resolved (and cleared)
    // above; only a barrier/back/drag dismissal reaches here with
    // `_completedRegion` still set.
    if (mounted && _completedRegion != null) {
      _cancelRegionSelection(bloc);
    }
  }

  void _resolveRegionSelection(
    ScoreBloc bloc,
    Region region,
    RegionIntent intent,
  ) {
    bloc
      ..add(RegionSelectStarted(intent))
      ..add(RegionSelectCompleted(region));
    setState(() => _completedRegion = null);
  }

  void _cancelRegionSelection(ScoreBloc bloc) {
    bloc.add(const RegionSelectionCleared());
    setState(() => _completedRegion = null);
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
  /// itself a path (see
  /// `_ScoreViewerScreenState._saveAudioNote`).
  Future<void> _playNote(
    AudioPlaybackCubit playbackCubit,
    AudioNote note,
  ) async {
    final pathResult = await widget.audioAssetStore.pathFor(
      note.audioAssetId,
    );
    final path = switch (pathResult) {
      Success<String>(:final value) => value,
      // Falls back to treating the id as a path directly — covers a note
      // saved before this asset-store wiring existed.
      ResultFailure<String>() => note.audioAssetId,
    };
    await playbackCubit.play(note.id, path);
  }
}

/// The top-right [PlaybackChip], shown whenever a note is playing —
/// resolves the author's name/colour from [state]'s layers and formats
/// `mm:ss` from the cubit's real playback progress (never a fake waveform).
class _PlayingChip extends StatelessWidget {
  const _PlayingChip({required this.state});

  final ScoreState state;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioPlaybackCubit, AudioPlaybackState>(
      builder: (context, playback) {
        final noteId = playback.noteId;
        if (playback.status != AudioPlaybackStatus.playing || noteId == null) {
          return const SizedBox.shrink();
        }
        AudioNote? note;
        for (final candidate in state.notes) {
          if (candidate.id == noteId) {
            note = candidate;
            break;
          }
        }
        if (note == null) return const SizedBox.shrink();
        ParticipantLayer? author;
        for (final layer in state.layers) {
          if (layer.ownerId == note.authorId) {
            author = layer;
            break;
          }
        }
        final authorName = author?.label ?? 'Someone';
        final progress = playback.progress;
        return Positioned(
          right: AppSpacing.md,
          top: AppSpacing.md,
          child: PlaybackChip(
            authorInitials: _initialsFor(authorName),
            authorColor: _avatarColorFor(note.authorId),
            authorName: authorName,
            positionLabel: _formatDuration(progress?.position ?? Duration.zero),
            durationLabel: _formatDuration(progress?.duration ?? Duration.zero),
            progress: progress == null || progress.duration == Duration.zero
                ? null
                : progress.position.inMilliseconds /
                      progress.duration.inMilliseconds,
          ),
        );
      },
    );
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
