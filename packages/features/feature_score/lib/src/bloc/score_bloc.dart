import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_score/src/ink_color_id.dart';
import 'package:feature_score/src/participant_layer.dart';
import 'package:pieces/pieces.dart';

part 'score_event.dart';
part 'score_state.dart';

/// Drives the Score Viewer: opens a [Piece], subscribes to its live
/// annotations, and mediates every drawing/region-select/undo interaction
/// against [AnnotationRepository].
///
/// Recording and playback are deliberately **not** handled here — see
/// `RecordAudioCubit`/`AudioPlaybackCubit` — so this bloc only ever deals in
/// [InkStroke]s/[AudioNote]s already resolved to disk, never raw audio
/// files.
class ScoreBloc extends Bloc<ScoreEvent, ScoreState> {
  /// Creates a [ScoreBloc] for [currentUserId]. [clock] is injectable for
  /// tests; it defaults to the real wall clock and is used only to mint
  /// stable, ordered ids for locally-authored strokes.
  ScoreBloc({
    required PieceRepository pieceRepository,
    required AnnotationRepository annotationRepository,
    required String currentUserId,
    DateTime Function()? clock,
  }) : _pieceRepository = pieceRepository,
       _annotationRepository = annotationRepository,
       _now = clock ?? DateTime.now,
       super(ScoreState.initial(currentUserId: currentUserId)) {
    on<ScoreOpened>(_onOpened);
    on<ScoreAnnotationsUpdated>(_onAnnotationsUpdated);
    on<PageChanged>(_onPageChanged);
    on<ModeChanged>(_onModeChanged);
    on<InkLayerToggled>(_onInkLayerToggled);
    on<AudioPinsToggled>(_onAudioPinsToggled);
    on<CleanWorkspaceToggled>(_onCleanWorkspaceToggled);
    on<EraserToggled>(_onEraserToggled);
    on<StrokeCompleted>(_onStrokeCompleted);
    on<StrokeErased>(_onStrokeErased);
    on<UndoRequested>(_onUndoRequested);
    on<RegionSelectStarted>(_onRegionSelectStarted);
    on<RegionDragUpdated>(_onRegionDragUpdated);
    on<RegionSelectCompleted>(_onRegionSelectCompleted);
    on<RegionSelectionCleared>(_onRegionSelectionCleared);
    on<AudioNoteSaved>(_onAudioNoteSaved);
    on<AudioNoteDeleteRequested>(_onAudioNoteDeleteRequested);
  }

  final PieceRepository _pieceRepository;
  final AnnotationRepository _annotationRepository;
  final DateTime Function() _now;
  StreamSubscription<PieceAnnotations>? _annotationsSubscription;
  int _strokeSeq = 0;

  String _nextStrokeId() =>
      'stroke_${_now().microsecondsSinceEpoch}_${_strokeSeq++}';

  Future<void> _onOpened(ScoreOpened event, Emitter<ScoreState> emit) async {
    await _annotationsSubscription?.cancel();
    emit(
      state.copyWith(
        status: ScoreStatus.loading,
        pieceId: event.pieceId,
        clearError: true,
      ),
    );
    final result = await _pieceRepository.getPiece(event.pieceId);
    switch (result) {
      case Success<Piece>(:final value):
        final role = value.teacherId == state.currentUserId
            ? PieceRole.teacher
            : PieceRole.student;
        emit(
          state.copyWith(
            status: ScoreStatus.ready,
            piece: value,
            currentRole: role,
            currentPage: 0,
          ),
        );
        _annotationsSubscription = _annotationRepository
            .watch(value.id)
            .listen(
              (annotations) => add(ScoreAnnotationsUpdated(annotations)),
            );
      case ResultFailure<Piece>(:final error):
        emit(state.copyWith(status: ScoreStatus.failure, error: '$error'));
    }
  }

  void _onAnnotationsUpdated(
    ScoreAnnotationsUpdated event,
    Emitter<ScoreState> emit,
  ) {
    final piece = state.piece;
    if (piece == null) return;
    emit(
      state.copyWith(
        layers: _projectLayers(piece, event.annotations, state),
        notes: event.annotations.audioNotes,
      ),
    );
  }

  /// Projects one [ParticipantLayer] per participant on [piece] (its owner
  /// plus every collaborator), in [Piece.participantIds] order — assigning
  /// each a distinct, palette-cycling colour and carrying that participant's
  /// strokes (or none). Each layer's `visible` reflects the current
  /// [ScoreState.hiddenInkOwnerIds], so toggles survive a re-derive.
  List<ParticipantLayer> _projectLayers(
    Piece piece,
    PieceAnnotations annotations,
    ScoreState state,
  ) {
    final participantIds = piece.participantIds;
    return [
      for (var i = 0; i < participantIds.length; i++)
        ParticipantLayer(
          ownerId: participantIds[i],
          label: _labelForParticipant(piece, participantIds[i], i),
          colorId: inkColorIdFor(i),
          strokes: _strokesForOwner(annotations, participantIds[i]),
          visible: !state.hiddenInkOwnerIds.contains(participantIds[i]),
          isOwn: participantIds[i] == state.currentUserId,
        ),
    ];
  }

  List<InkStroke> _strokesForOwner(PieceAnnotations annotations, String owner) {
    for (final layer in annotations.layers) {
      if (layer.ownerId == owner) return layer.strokes;
    }
    return const [];
  }

  /// A display label for the participant at [index] in [Piece.participantIds]:
  /// the owner's/collaborator's name where known, else a stable fallback
  /// (`Owner`, or `Collaborator N` keyed on participant index so unnamed
  /// collaborators stay distinguishable).
  String _labelForParticipant(Piece piece, String ownerId, int index) {
    if (ownerId == piece.teacherId) return piece.teacherName ?? 'Owner';
    for (final collaborator in piece.collaborators) {
      if (collaborator.uid == ownerId) {
        return collaborator.name ?? 'Collaborator $index';
      }
    }
    return 'Collaborator $index';
  }

  void _onPageChanged(PageChanged event, Emitter<ScoreState> emit) {
    emit(state.copyWith(currentPage: event.page));
  }

  void _onModeChanged(ModeChanged event, Emitter<ScoreState> emit) {
    final leavingRegionSelect =
        state.mode == ScoreMode.regionSelect &&
        event.mode != ScoreMode.regionSelect;
    emit(
      state.copyWith(
        mode: event.mode,
        clearActiveRegion: leavingRegionSelect,
        clearRegionIntent: leavingRegionSelect,
      ),
    );
  }

  void _onInkLayerToggled(InkLayerToggled event, Emitter<ScoreState> emit) {
    final hidden = {...state.hiddenInkOwnerIds};
    if (!hidden.remove(event.ownerId)) hidden.add(event.ownerId);
    emit(
      state.copyWith(
        hiddenInkOwnerIds: hidden,
        layers: [
          for (final layer in state.layers)
            layer.copyWith(visible: !hidden.contains(layer.ownerId)),
        ],
      ),
    );
  }

  void _onAudioPinsToggled(AudioPinsToggled event, Emitter<ScoreState> emit) {
    emit(state.copyWith(audioPinsVisible: !state.audioPinsVisible));
  }

  void _onCleanWorkspaceToggled(
    CleanWorkspaceToggled event,
    Emitter<ScoreState> emit,
  ) {
    // Flips only the transient mask; the three per-layer flags are never
    // read or written here, so toggling clean-workspace off always restores
    // exactly what was visible before it was toggled on.
    emit(state.copyWith(cleanWorkspace: !state.cleanWorkspace));
  }

  void _onEraserToggled(EraserToggled event, Emitter<ScoreState> emit) {
    emit(state.copyWith(eraserActive: !state.eraserActive));
  }

  Future<void> _onStrokeCompleted(
    StrokeCompleted event,
    Emitter<ScoreState> emit,
  ) async {
    final piece = state.piece;
    if (piece == null ||
        state.mode != ScoreMode.draw ||
        event.points.length < 2) {
      return;
    }
    final stroke = InkStroke(
      id: _nextStrokeId(),
      authorId: state.currentUserId,
      pageIndex: state.currentPage,
      // Auto-assigned: a participant always draws in their own layer colour,
      // resolved from their position on the piece rather than a manual pick.
      colorId: inkColorIdFor(piece.participantIds.indexOf(state.currentUserId)),
      points: event.points,
    );
    // Pushed onto the session-local undo stack optimistically; the
    // authoritative per-participant layers only update once the repository's
    // stream re-emits, avoiding a second source of truth.
    emit(state.copyWith(undoStack: [...state.undoStack, stroke]));
    final result = await _annotationRepository.addStroke(piece.id, stroke);
    if (result case ResultFailure<void>(:final error)) {
      emit(
        state.copyWith(
          error: '$error',
          undoStack: state.undoStack.where((s) => s.id != stroke.id).toList(),
        ),
      );
    }
  }

  Future<void> _onStrokeErased(
    StrokeErased event,
    Emitter<ScoreState> emit,
  ) async {
    final piece = state.piece;
    if (piece == null) return;
    final ownStrokes = state.ownLayer?.strokes ?? const <InkStroke>[];
    // The UI should never surface an erase gesture for another participant's
    // layer; this is the bloc-side backstop before the repository's own
    // ownership guard.
    if (!ownStrokes.any((s) => s.id == event.strokeId)) return;
    final result = await _annotationRepository.eraseStroke(
      piece.id,
      event.strokeId,
    );
    switch (result) {
      case Success<void>():
        emit(
          state.copyWith(
            undoStack: state.undoStack
                .where((s) => s.id != event.strokeId)
                .toList(),
          ),
        );
      case ResultFailure<void>(:final error):
        emit(state.copyWith(error: '$error'));
    }
  }

  Future<void> _onUndoRequested(
    UndoRequested event,
    Emitter<ScoreState> emit,
  ) async {
    final piece = state.piece;
    if (piece == null || state.undoStack.isEmpty) return;
    final last = state.undoStack.last;
    final result = await _annotationRepository.eraseStroke(piece.id, last.id);
    switch (result) {
      case Success<void>():
        emit(
          state.copyWith(
            undoStack: state.undoStack.sublist(
              0,
              state.undoStack.length - 1,
            ),
          ),
        );
      case ResultFailure<void>(:final error):
        emit(state.copyWith(error: '$error'));
    }
  }

  void _onRegionSelectStarted(
    RegionSelectStarted event,
    Emitter<ScoreState> emit,
  ) {
    emit(
      state.copyWith(
        mode: ScoreMode.regionSelect,
        regionIntent: event.intent,
        clearActiveRegion: true,
      ),
    );
  }

  void _onRegionDragUpdated(
    RegionDragUpdated event,
    Emitter<ScoreState> emit,
  ) {
    emit(state.copyWith(activeRegion: event.rect));
  }

  void _onRegionSelectCompleted(
    RegionSelectCompleted event,
    Emitter<ScoreState> emit,
  ) {
    emit(state.copyWith(activeRegion: event.rect));
  }

  void _onRegionSelectionCleared(
    RegionSelectionCleared event,
    Emitter<ScoreState> emit,
  ) {
    emit(state.copyWith(clearActiveRegion: true, clearRegionIntent: true));
  }

  Future<void> _onAudioNoteSaved(
    AudioNoteSaved event,
    Emitter<ScoreState> emit,
  ) async {
    final piece = state.piece;
    if (piece == null) return;
    final result = await _annotationRepository.addAudioNote(
      piece.id,
      event.note,
    );
    if (result case ResultFailure<void>(:final error)) {
      emit(state.copyWith(error: '$error'));
    }
  }

  Future<void> _onAudioNoteDeleteRequested(
    AudioNoteDeleteRequested event,
    Emitter<ScoreState> emit,
  ) async {
    final piece = state.piece;
    if (piece == null) return;
    final owns = state.notes.any(
      (note) => note.id == event.noteId && note.authorId == state.currentUserId,
    );
    if (!owns) return;
    final result = await _annotationRepository.deleteAudioNote(
      piece.id,
      event.noteId,
    );
    if (result case ResultFailure<void>(:final error)) {
      emit(state.copyWith(error: '$error'));
    }
  }

  @override
  Future<void> close() async {
    await _annotationsSubscription?.cancel();
    return super.close();
  }
}
