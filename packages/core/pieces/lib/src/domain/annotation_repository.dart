import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:pieces/src/domain/audio_note.dart';
import 'package:pieces/src/domain/ink_layer.dart';
import 'package:pieces/src/domain/ink_stroke.dart';

/// The combined ink and audio annotations for a single piece.
class PieceAnnotations extends Equatable {
  /// Creates a [PieceAnnotations].
  const PieceAnnotations({
    required this.pieceId,
    required this.layers,
    required this.audioNotes,
  });

  /// An empty set of annotations for [pieceId].
  factory PieceAnnotations.empty(String pieceId) => PieceAnnotations(
    pieceId: pieceId,
    layers: const [],
    audioNotes: const [],
  );

  /// The id of the piece these annotations belong to.
  final String pieceId;

  /// Each participant's ink layer.
  final List<InkLayer> layers;

  /// The audio notes pinned to the piece.
  final List<AudioNote> audioNotes;

  @override
  List<Object?> get props => [pieceId, layers, audioNotes];
}

/// Contract for reading and mutating a piece's ink strokes and audio notes.
///
/// Implementations are constructed with a `currentUserId` callback so every
/// mutation can guard ownership (e.g. a student erasing the teacher's stroke
/// fails with an ownership-violation failure) without each call site
/// re-deriving "who am I".
abstract class AnnotationRepository {
  /// Emits the current [PieceAnnotations] for [pieceId], updating as ink
  /// strokes and audio notes are added or removed.
  Stream<PieceAnnotations> watch(String pieceId);

  /// Appends [stroke] to [pieceId]'s ink layer for its author.
  Future<Result<void>> addStroke(String pieceId, InkStroke stroke);

  /// Erases the stroke identified by [strokeId] from [pieceId]. Fails with
  /// an ownership-violation failure if the caller doesn't own it.
  Future<Result<void>> eraseStroke(String pieceId, String strokeId);

  /// Adds [note] to [pieceId].
  Future<Result<void>> addAudioNote(String pieceId, AudioNote note);

  /// Deletes the audio note identified by [noteId] from [pieceId]. Fails
  /// with an ownership-violation failure if the caller doesn't own it.
  Future<Result<void>> deleteAudioNote(String pieceId, String noteId);
}
