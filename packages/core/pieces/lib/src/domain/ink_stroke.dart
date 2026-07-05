import 'package:equatable/equatable.dart';

/// A single point on an [InkStroke], expressed as fractional coordinates
/// (0.0-1.0 of the rendered page's width/height) so strokes stay aligned
/// across devices and zoom levels.
class InkPoint extends Equatable {
  /// Creates an [InkPoint].
  const InkPoint({required this.x, required this.y});

  /// The fractional horizontal position (0.0-1.0).
  final double x;

  /// The fractional vertical position (0.0-1.0).
  final double y;

  @override
  List<Object?> get props => [x, y];
}

/// A single freehand stroke drawn by [authorId] on page [pageIndex] of a
/// piece.
class InkStroke extends Equatable {
  /// Creates an [InkStroke].
  const InkStroke({
    required this.id,
    required this.authorId,
    required this.pageIndex,
    required this.colorId,
    required this.points,
  });

  /// The stable identifier for this stroke.
  final String id;

  /// The id of the participant who drew this stroke.
  final String authorId;

  /// The zero-based page index the stroke was drawn on.
  final int pageIndex;

  /// A palette-relative identifier for the stroke's colour.
  final String colorId;

  /// The ordered points making up the stroke's path.
  final List<InkPoint> points;

  @override
  List<Object?> get props => [id, authorId, pageIndex, colorId, points];
}
