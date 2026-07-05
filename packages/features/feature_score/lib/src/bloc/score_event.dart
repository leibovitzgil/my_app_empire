part of 'score_bloc.dart';

sealed class ScoreEvent extends Equatable {
  const ScoreEvent();

  @override
  List<Object?> get props => [];
}

/// Opens the piece identified by [pieceId]: loads it and subscribes to its
/// live annotations.
final class ScoreOpened extends ScoreEvent {
  const ScoreOpened(this.pieceId);

  final String pieceId;

  @override
  List<Object?> get props => [pieceId];
}

/// Internal: fired whenever `AnnotationRepository.watch` emits a new
/// snapshot, so the bloc can re-derive per-layer stroke lists and notes.
final class ScoreAnnotationsUpdated extends ScoreEvent {
  const ScoreAnnotationsUpdated(this.annotations);

  final PieceAnnotations annotations;

  @override
  List<Object?> get props => [annotations];
}

/// The visible page changed (pagination/scroll).
final class PageChanged extends ScoreEvent {
  const PageChanged(this.page);

  final int page;

  @override
  List<Object?> get props => [page];
}

/// The interaction mode changed. Draw and region-select are mutually
/// exclusive by construction (a single [ScoreState.mode] field); selecting
/// [ScoreMode.view] exits either.
final class ModeChanged extends ScoreEvent {
  const ModeChanged(this.mode);

  final ScoreMode mode;

  @override
  List<Object?> get props => [mode];
}

/// A participant's ink-layer visibility chip was tapped, identified by its
/// [ownerId]. Presentation-layer only — never touches
/// [ScoreState.cleanWorkspace].
final class InkLayerToggled extends ScoreEvent {
  const InkLayerToggled(this.ownerId);

  final String ownerId;

  @override
  List<Object?> get props => [ownerId];
}

/// The audio-pins visibility chip was tapped. Presentation-layer only — never
/// touches [ScoreState.cleanWorkspace].
final class AudioPinsToggled extends ScoreEvent {
  const AudioPinsToggled();
}

/// Flips the transient clean-workspace mask, leaving the three per-layer
/// visibility flags untouched so toggling it back off restores exactly what
/// was visible before.
final class CleanWorkspaceToggled extends ScoreEvent {
  const CleanWorkspaceToggled();
}

/// Toggles the eraser tool on/off.
final class EraserToggled extends ScoreEvent {
  const EraserToggled();
}

/// A freehand stroke was finished being drawn on the current user's own
/// layer. Only valid in [ScoreMode.draw].
final class StrokeCompleted extends ScoreEvent {
  const StrokeCompleted(this.points);

  final List<InkPoint> points;

  @override
  List<Object?> get props => [points];
}

/// The current user erased one of their own strokes, identified by
/// [strokeId]. The UI is expected to only ever surface this gesture for the
/// current user's own layer.
final class StrokeErased extends ScoreEvent {
  const StrokeErased(this.strokeId);

  final String strokeId;

  @override
  List<Object?> get props => [strokeId];
}

/// Pops and erases the most recent own-layer stroke added this session.
final class UndoRequested extends ScoreEvent {
  const UndoRequested();
}

/// A region-select drag has begun for [intent] (record a new audio note, or
/// practice the selected passage).
final class RegionSelectStarted extends ScoreEvent {
  const RegionSelectStarted(this.intent);

  final RegionIntent intent;

  @override
  List<Object?> get props => [intent];
}

/// The in-progress region-select drag rectangle changed; mirrors the live
/// drag preview into state.
final class RegionDragUpdated extends ScoreEvent {
  const RegionDragUpdated(this.rect);

  final Region rect;

  @override
  List<Object?> get props => [rect];
}

/// The region-select drag finished with a final [rect]. The UI reacts to the
/// resulting `activeRegion`/`regionIntent` pair by showing the record-audio
/// sheet or navigating to the practice view.
final class RegionSelectCompleted extends ScoreEvent {
  const RegionSelectCompleted(this.rect);

  final Region rect;

  @override
  List<Object?> get props => [rect];
}

/// Clears `activeRegion`/`regionIntent` once the UI has acted on them (sheet
/// dismissed, or practice view popped), without changing [ScoreMode].
final class RegionSelectionCleared extends ScoreEvent {
  const RegionSelectionCleared();
}

/// A recording produced by `RecordAudioCubit` (the file at [path]) was
/// confirmed by the user as [note].
final class AudioNoteSaved extends ScoreEvent {
  const AudioNoteSaved(this.note, this.path);

  final AudioNote note;
  final String path;

  @override
  List<Object?> get props => [note, path];
}

/// The current user asked to delete their own audio note [noteId].
final class AudioNoteDeleteRequested extends ScoreEvent {
  const AudioNoteDeleteRequested(this.noteId);

  final String noteId;

  @override
  List<Object?> get props => [noteId];
}
