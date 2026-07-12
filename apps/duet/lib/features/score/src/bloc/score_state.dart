part of 'score_bloc.dart';

/// High-level phase of the Score Viewer.
enum ScoreStatus { loading, ready, failure }

/// The current interaction mode. Mutually exclusive by construction (a
/// single field): selecting one deselects any other.
enum ScoreMode { view, draw, regionSelect }

/// What a region-select gesture is for.
enum RegionIntent { recordAudio, practice }

/// Immutable state for [ScoreBloc].
final class ScoreState extends Equatable {
  const ScoreState._({
    required this.currentUserId,
    this.status = ScoreStatus.loading,
    this.pieceId,
    this.piece,
    this.currentPage = 0,
    this.pageCount = 1,
    this.layers = const [],
    this.notes = const [],
    this.currentRole = PieceRole.collaborator,
    this.mode = ScoreMode.view,
    this.eraserActive = false,
    this.undoStack = const [],
    this.activeRegion,
    this.regionIntent,
    this.hiddenInkOwnerIds = const {},
    this.audioPinsVisible = true,
    this.cleanWorkspace = false,
    this.error,
  });

  /// The initial state before [ScoreOpened] resolves.
  const ScoreState.initial({required String currentUserId})
    : this._(currentUserId: currentUserId);

  /// The current phase.
  final ScoreStatus status;

  /// The id of the piece [ScoreOpened] was last dispatched for, kept even on
  /// failure so the UI can retry.
  final String? pieceId;

  /// The loaded piece, once [status] is [ScoreStatus.ready] (or was, before
  /// a later failure).
  final Piece? piece;

  /// The zero-based page currently shown.
  final int currentPage;

  /// The piece's total page count, resolved from [PageCountResolved] once
  /// the PDF has been opened (see `ScoreViewerScreen`). Defaults to 1 so
  /// [isLastPage] is meaningful even before that resolves.
  final int pageCount;

  /// Every participant's ink, one [ParticipantLayer] per participant on the
  /// piece (its owner plus every collaborator), in [Piece.participantIds]
  /// order. Re-derived from the annotations stream on each snapshot; each
  /// layer's `visible` flag reflects [hiddenInkOwnerIds].
  final List<ParticipantLayer> layers;

  /// The piece's audio notes, across all pages.
  final List<AudioNote> notes;

  /// The signed-in participant's id.
  final String currentUserId;

  /// Whether the signed-in participant owns the piece or is a
  /// collaborator on it.
  final PieceRole currentRole;

  /// The current interaction mode.
  final ScoreMode mode;

  /// Whether the eraser tool is active (instead of the pen).
  final bool eraserActive;

  /// Own-layer strokes added this session, most-recent-last, so
  /// [UndoRequested] can pop and erase them in order. Session-local: never
  /// rebuilt from the repository's historical data.
  final List<InkStroke> undoStack;

  /// The in-progress or just-completed region-select rectangle.
  final Region? activeRegion;

  /// What [activeRegion] is for, once known.
  final RegionIntent? regionIntent;

  /// The owner ids whose ink layers are currently toggled off. The
  /// source-of-truth visibility set for per-participant ink, mirrored onto
  /// each [ParticipantLayer.visible] so it survives an annotations re-derive.
  /// Never mutated by [CleanWorkspaceToggled].
  final Set<String> hiddenInkOwnerIds;

  /// Source-of-truth visibility of audio pin markers. Never mutated by
  /// [CleanWorkspaceToggled].
  final bool audioPinsVisible;

  /// A transient mask: when true, every layer renders hidden regardless of
  /// its own visibility flag, without changing that flag. See
  /// [effectiveInkVisible]/[effectiveAudioPinsVisible] for the actual,
  /// computed visibility.
  final bool cleanWorkspace;

  /// The most recent (usually transient/non-blocking) error, if any.
  final String? error;

  /// Whether [currentPage] is the first page.
  bool get isFirstPage => currentPage <= 0;

  /// Whether [currentPage] is the last page.
  bool get isLastPage => currentPage >= pageCount - 1;

  /// The signed-in participant's own layer, if it has been projected yet.
  ParticipantLayer? get ownLayer {
    for (final layer in layers) {
      if (layer.isOwn) return layer;
    }
    return null;
  }

  /// Effective visibility of [layer] = `!cleanWorkspace && layer.visible`.
  /// Computed, never stored, so clean-workspace can never clobber the
  /// underlying per-layer flag.
  bool effectiveInkVisible(ParticipantLayer layer) =>
      !cleanWorkspace && layer.visible;

  /// Effective visibility = `!cleanWorkspace && audioPinsVisible`. Computed,
  /// never stored, so clean-workspace can never clobber the underlying flag.
  bool get effectiveAudioPinsVisible => !cleanWorkspace && audioPinsVisible;

  /// Returns a copy with the given fields replaced. `clear*` flags exist for
  /// the nullable fields that sometimes need to be reset to null rather than
  /// left as-is.
  ScoreState copyWith({
    ScoreStatus? status,
    String? pieceId,
    Piece? piece,
    int? currentPage,
    int? pageCount,
    List<ParticipantLayer>? layers,
    List<AudioNote>? notes,
    PieceRole? currentRole,
    ScoreMode? mode,
    bool? eraserActive,
    List<InkStroke>? undoStack,
    Region? activeRegion,
    bool clearActiveRegion = false,
    RegionIntent? regionIntent,
    bool clearRegionIntent = false,
    Set<String>? hiddenInkOwnerIds,
    bool? audioPinsVisible,
    bool? cleanWorkspace,
    String? error,
    bool clearError = false,
  }) {
    return ScoreState._(
      currentUserId: currentUserId,
      status: status ?? this.status,
      pieceId: pieceId ?? this.pieceId,
      piece: piece ?? this.piece,
      currentPage: currentPage ?? this.currentPage,
      pageCount: pageCount ?? this.pageCount,
      layers: layers ?? this.layers,
      notes: notes ?? this.notes,
      currentRole: currentRole ?? this.currentRole,
      mode: mode ?? this.mode,
      eraserActive: eraserActive ?? this.eraserActive,
      undoStack: undoStack ?? this.undoStack,
      activeRegion: clearActiveRegion
          ? null
          : (activeRegion ?? this.activeRegion),
      regionIntent: clearRegionIntent
          ? null
          : (regionIntent ?? this.regionIntent),
      hiddenInkOwnerIds: hiddenInkOwnerIds ?? this.hiddenInkOwnerIds,
      audioPinsVisible: audioPinsVisible ?? this.audioPinsVisible,
      cleanWorkspace: cleanWorkspace ?? this.cleanWorkspace,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    status,
    pieceId,
    piece,
    currentPage,
    pageCount,
    layers,
    notes,
    currentUserId,
    currentRole,
    mode,
    eraserActive,
    undoStack,
    activeRegion,
    regionIntent,
    hiddenInkOwnerIds,
    audioPinsVisible,
    cleanWorkspace,
    error,
  ];
}
