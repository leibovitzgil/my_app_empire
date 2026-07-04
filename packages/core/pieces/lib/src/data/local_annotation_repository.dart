import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:pieces/src/domain/annotation_repository.dart';
import 'package:pieces/src/domain/audio_note.dart';
import 'package:pieces/src/domain/ink_layer.dart';
import 'package:pieces/src/domain/ink_stroke.dart';
import 'package:pieces/src/domain/ownership.dart';

/// An in-memory [AnnotationRepository]. Real persistence (e.g. Firestore)
/// lands in a later phase; ownership enforcement (guarded by
/// [_currentUserId]) is already wired so callers can rely on it from the
/// start.
class LocalAnnotationRepository implements AnnotationRepository {
  /// Creates a [LocalAnnotationRepository], guarding mutating calls with
  /// [currentUserId].
  LocalAnnotationRepository({required String Function() currentUserId})
    : _currentUserId = currentUserId;

  final String Function() _currentUserId;
  final _annotations = <String, PieceAnnotations>{};
  final _controller = StreamController<PieceAnnotations>.broadcast();

  PieceAnnotations _annotationsFor(String pieceId) =>
      _annotations[pieceId] ?? PieceAnnotations.empty(pieceId);

  void _emit(String pieceId, PieceAnnotations annotations) {
    _annotations[pieceId] = annotations;
    _controller.add(annotations);
  }

  @override
  Stream<PieceAnnotations> watch(String pieceId) =>
      _controller.stream.where((a) => a.pieceId == pieceId);

  @override
  Future<Result<void>> addStroke(String pieceId, InkStroke stroke) async {
    final current = _annotationsFor(pieceId);
    final authorId = stroke.authorId;
    final existing = current.layers.where((l) => l.ownerId == authorId);
    final layer = existing.isEmpty
        ? InkLayer(
            ownerId: authorId,
            role: PieceRole.teacher,
            strokes: [
              stroke,
            ],
          )
        : existing.first.copyWith(strokes: [...existing.first.strokes, stroke]);
    _emit(
      pieceId,
      PieceAnnotations(
        pieceId: pieceId,
        layers: [
          ...current.layers.where((l) => l.ownerId != authorId),
          layer,
        ],
        audioNotes: current.audioNotes,
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> eraseStroke(String pieceId, String strokeId) async {
    final current = _annotationsFor(pieceId);
    for (final layer in current.layers) {
      final match = layer.strokes.where((s) => s.id == strokeId);
      if (match.isEmpty) continue;
      if (match.first.authorId != _currentUserId()) {
        return ResultFailure<void>(
          OwnershipViolation(strokeId, reason: 'not the stroke author'),
        );
      }
      final updatedStrokes = [...layer.strokes]
        ..removeWhere((s) => s.id == strokeId);
      _emit(
        pieceId,
        PieceAnnotations(
          pieceId: pieceId,
          layers: [
            for (final l in current.layers)
              if (l.ownerId == layer.ownerId)
                l.copyWith(strokes: updatedStrokes)
              else
                l,
          ],
          audioNotes: current.audioNotes,
        ),
      );
      return const Success(null);
    }
    return ResultFailure<void>(StateError('Unknown stroke: $strokeId'));
  }

  @override
  Future<Result<void>> addAudioNote(String pieceId, AudioNote note) async {
    final current = _annotationsFor(pieceId);
    _emit(
      pieceId,
      PieceAnnotations(
        pieceId: pieceId,
        layers: current.layers,
        audioNotes: [...current.audioNotes, note],
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteAudioNote(String pieceId, String noteId) async {
    final current = _annotationsFor(pieceId);
    final match = current.audioNotes.where((n) => n.id == noteId);
    if (match.isEmpty) {
      return ResultFailure<void>(StateError('Unknown audio note: $noteId'));
    }
    if (match.first.authorId != _currentUserId()) {
      return ResultFailure<void>(
        OwnershipViolation(noteId, reason: 'not the note author'),
      );
    }
    _emit(
      pieceId,
      PieceAnnotations(
        pieceId: pieceId,
        layers: current.layers,
        audioNotes: current.audioNotes.where((n) => n.id != noteId).toList(),
      ),
    );
    return const Success(null);
  }
}
