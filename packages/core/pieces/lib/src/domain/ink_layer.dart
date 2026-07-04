import 'package:equatable/equatable.dart';
import 'package:pieces/src/domain/ink_stroke.dart';

/// Which side of a piece's collaboration a participant is on.
enum PieceRole {
  /// The piece's owner, who imported it.
  teacher,

  /// The participant paired on the piece by the teacher.
  student,
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

  /// Whether [ownerId] is the teacher or the student on the piece.
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
