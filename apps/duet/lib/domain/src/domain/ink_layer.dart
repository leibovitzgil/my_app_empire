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
    this.updatedAt,
  });

  /// The id of the participant this layer belongs to.
  final String ownerId;

  /// Whether [ownerId] is the owner of or a collaborator on the piece.
  final PieceRole role;

  /// The strokes this participant has drawn.
  final List<InkStroke> strokes;

  /// When this layer was last written, if known — the cloud layer document's
  /// `updatedAt` (M3.2). Drives the reader's "new since you last looked"
  /// markers (M4.3); `null` on backends that don't stamp it (the on-device
  /// store), where there's no cross-participant newness to show.
  final DateTime? updatedAt;

  /// Returns a copy with [strokes] and/or [updatedAt] replaced.
  InkLayer copyWith({List<InkStroke>? strokes, DateTime? updatedAt}) {
    return InkLayer(
      ownerId: ownerId,
      role: role,
      strokes: strokes ?? this.strokes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [ownerId, role, strokes, updatedAt];
}
