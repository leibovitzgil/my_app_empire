part of 'score_bloc.dart';

/// High-level phase of the Score Viewer.
enum ScoreStatus { loading, ready, failure }

/// The current interaction mode. Mutually exclusive by construction (a
/// single field): selecting one deselects any other.
enum ScoreMode { view, draw, regionSelect }

/// The three annotation layers a user can toggle visibility for.
enum LayerKind { teacherInk, studentInk, audioPins }

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
    this.teacherStrokes = const [],
    this.studentStrokes = const [],
    this.notes = const [],
    this.currentRole = PieceRole.student,
    this.mode = ScoreMode.view,
    this.selectedColorId = 0,
    this.eraserActive = false,
    this.undoStack = const [],
    this.activeRegion,
    this.regionIntent,
    this.teacherInkVisible = true,
    this.studentInkVisible = true,
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

  /// The teacher's ink strokes, across all pages.
  final List<InkStroke> teacherStrokes;

  /// The student's ink strokes, across all pages.
  final List<InkStroke> studentStrokes;

  /// The piece's audio notes, across all pages.
  final List<AudioNote> notes;

  /// The signed-in participant's id.
  final String currentUserId;

  /// Whether the signed-in participant is the piece's teacher or student.
  final PieceRole currentRole;

  /// The current interaction mode.
  final ScoreMode mode;

  /// The index (into the fixed ink palette) of the currently selected pen
  /// colour.
  final int selectedColorId;

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

  /// Source-of-truth visibility of the teacher's ink layer. Never mutated by
  /// [CleanWorkspaceToggled].
  final bool teacherInkVisible;

  /// Source-of-truth visibility of the student's ink layer. Never mutated by
  /// [CleanWorkspaceToggled].
  final bool studentInkVisible;

  /// Source-of-truth visibility of audio pin markers. Never mutated by
  /// [CleanWorkspaceToggled].
  final bool audioPinsVisible;

  /// A transient mask: when true, every layer renders hidden regardless of
  /// its own visibility flag, without changing that flag. See
  /// [effectiveTeacherInkVisible] et al. for the actual, computed visibility.
  final bool cleanWorkspace;

  /// The most recent (usually transient/non-blocking) error, if any.
  final String? error;

  /// Effective visibility = `!cleanWorkspace && teacherInkVisible`. Computed,
  /// never stored, so clean-workspace can never clobber the underlying flag.
  bool get effectiveTeacherInkVisible => !cleanWorkspace && teacherInkVisible;

  /// Effective visibility = `!cleanWorkspace && studentInkVisible`. Computed,
  /// never stored, so clean-workspace can never clobber the underlying flag.
  bool get effectiveStudentInkVisible => !cleanWorkspace && studentInkVisible;

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
    List<InkStroke>? teacherStrokes,
    List<InkStroke>? studentStrokes,
    List<AudioNote>? notes,
    PieceRole? currentRole,
    ScoreMode? mode,
    int? selectedColorId,
    bool? eraserActive,
    List<InkStroke>? undoStack,
    Region? activeRegion,
    bool clearActiveRegion = false,
    RegionIntent? regionIntent,
    bool clearRegionIntent = false,
    bool? teacherInkVisible,
    bool? studentInkVisible,
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
      teacherStrokes: teacherStrokes ?? this.teacherStrokes,
      studentStrokes: studentStrokes ?? this.studentStrokes,
      notes: notes ?? this.notes,
      currentRole: currentRole ?? this.currentRole,
      mode: mode ?? this.mode,
      selectedColorId: selectedColorId ?? this.selectedColorId,
      eraserActive: eraserActive ?? this.eraserActive,
      undoStack: undoStack ?? this.undoStack,
      activeRegion: clearActiveRegion
          ? null
          : (activeRegion ?? this.activeRegion),
      regionIntent: clearRegionIntent
          ? null
          : (regionIntent ?? this.regionIntent),
      teacherInkVisible: teacherInkVisible ?? this.teacherInkVisible,
      studentInkVisible: studentInkVisible ?? this.studentInkVisible,
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
    teacherStrokes,
    studentStrokes,
    notes,
    currentUserId,
    currentRole,
    mode,
    selectedColorId,
    eraserActive,
    undoStack,
    activeRegion,
    regionIntent,
    teacherInkVisible,
    studentInkVisible,
    audioPinsVisible,
    cleanWorkspace,
    error,
  ];
}
