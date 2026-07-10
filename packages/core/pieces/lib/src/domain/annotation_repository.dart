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
/// mutation can guard ownership (e.g. one collaborator erasing another
/// participant's stroke fails with an ownership-violation failure) without
/// each call site
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

  /// Deletes every stroke and audio note on [pieceId], regardless of author
  /// (e.g. when the piece itself is deleted). Not ownership-gated: callers
  /// are expected to have already checked the caller may delete the piece.
  Future<Result<void>> clearPiece(String pieceId);

  /// Wholesale-replaces [authorId]'s ink layer and audio notes on [pieceId]
  /// with [strokes] and [audioNotes], used to apply an imported review
  /// bundle. Not ownership-gated by the caller's current user id — the
  /// caller (`ReviewSyncService`) is trusted to have already resolved
  /// [authorId] and staleness before calling this.
  Future<Result<void>> replaceAuthorSlice(
    String pieceId,
    String authorId, {
    required PieceRole role,
    required List<InkStroke> strokes,
    required List<AudioNote> audioNotes,
  });

  /// Drops [authorId]'s ink layer and audio notes on [pieceId] entirely,
  /// used when they're removed as a collaborator (owner-removed, or they
  /// left themself). Privileged and non-gated by the caller's current user
  /// id, mirroring [replaceAuthorSlice] — the caller (`PieceRepository`) is
  /// trusted to have already authorized the removal itself.
  Future<Result<void>> removeAuthorSlice(String pieceId, String authorId);
}
