import 'package:duet/domain/src/domain/ink_stroke.dart';
import 'package:equatable/equatable.dart';

/// Which side of a piece's collaboration a participant is on.
enum PieceRole {
  /// The piece's owner, who imported it.
  owner,

  /// A participant invited to collaborate on the piece by its owner.
  collaborator,
}

/// All ink strokes authored by a single participant ([ownerId]) on a piece.
class InkLayer extends Equatable {
  /// Creates an [InkLayer].
  const InkLayer({
    required this.ownerId,
    required this.role,
    required this.strokes,
  });

  /// The id of the participant this layer belongs to.
  final String ownerId;

  /// Whether [ownerId] is the owner of or a collaborator on the piece.
  final PieceRole role;

  /// The strokes this participant has drawn.
  final List<InkStroke> strokes;

  /// Returns a copy with [strokes] replaced.
  InkLayer copyWith({List<InkStroke>? strokes}) {
    return InkLayer(
      ownerId: ownerId,
      role: role,
      strokes: strokes ?? this.strokes,
    );
  }

  @override
  List<Object?> get props => [ownerId, role, strokes];
}
