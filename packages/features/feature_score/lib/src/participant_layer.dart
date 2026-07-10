import 'package:equatable/equatable.dart';
import 'package:pieces/pieces.dart';

/// One participant's ink on a piece, projected for the Score Viewer: their
/// identity ([ownerId]), a display [label], the auto-assigned [colorId] their
/// whole layer renders in, their [strokes], whether the layer is currently
/// shown ([visible]), and whether it belongs to the signed-in user ([isOwn]).
///
/// In collaboration mode a piece is shared between its owner and zero or more
/// collaborators, and each participant gets their own ink layer (see
/// `pieces`' `InkLayer`). `ScoreBloc` projects one of these per participant —
/// in [Piece.participantIds] order, each assigned a distinct palette colour —
/// so the viewer can render and toggle every collaborator's ink, rather than
/// the fixed owner/collaborator pair it modelled before.
final class ParticipantLayer extends Equatable {
  /// Creates a [ParticipantLayer].
  const ParticipantLayer({
    required this.ownerId,
    required this.label,
    required this.colorId,
    required this.strokes,
    required this.visible,
    required this.isOwn,
  });

  /// The id of the participant this layer belongs to.
  final String ownerId;

  /// The participant's display name (their own, or a fallback when unknown).
  final String label;

  /// The palette colour id every stroke in this layer renders in — assigned
  /// by the participant's position on the piece, so a person's ink is one
  /// consistent, identifying colour (see `inkColorIdFor`).
  final String colorId;

  /// This participant's strokes, across all pages.
  final List<InkStroke> strokes;

  /// Whether this layer's ink is currently shown. This is the layer's own
  /// visibility toggle only — it does not account for the transient
  /// clean-workspace mask (see `ScoreState`).
  final bool visible;

  /// Whether this layer belongs to the signed-in participant, who may draw on
  /// and erase from it (and whose chip shows the owned indicator).
  final bool isOwn;

  /// Returns a copy with [visible] and/or [strokes] replaced.
  ParticipantLayer copyWith({bool? visible, List<InkStroke>? strokes}) {
    return ParticipantLayer(
      ownerId: ownerId,
      label: label,
      colorId: colorId,
      strokes: strokes ?? this.strokes,
      visible: visible ?? this.visible,
      isOwn: isOwn,
    );
  }

  @override
  List<Object?> get props => [
    ownerId,
    label,
    colorId,
    strokes,
    visible,
    isOwn,
  ];
}
