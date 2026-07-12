import 'package:duet/domain/domain.dart';
import 'package:flutter/material.dart';

/// Paints [strokes] for a single participant's ink layer on top of a rendered
/// page, all in that layer's [color] (auto-assigned per participant, so a
/// person's ink reads as one identifying colour regardless of what colour id
/// each stroke happens to carry).
///
/// Each [InkStroke.points] is fractional (0.0-1.0 of the page), so this
/// widget translates them into the actual size it's laid out at — it should
/// be sized to exactly match the rendered page (see `ScorePageCanvas`).
class InkOverlay extends StatelessWidget {
  /// Creates an [InkOverlay] for [strokes], drawing only those on
  /// [pageIndex], all in [color].
  const InkOverlay({
    required this.strokes,
    required this.pageIndex,
    required this.color,
    super.key,
  });

  /// The layer's strokes, across all pages (filtered to [pageIndex] here).
  final List<InkStroke> strokes;

  /// The page currently shown.
  final int pageIndex;

  /// The colour every stroke in this layer is painted in.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onPage = strokes.where((s) => s.pageIndex == pageIndex).toList();
    return IgnorePointer(
      child: CustomPaint(
        painter: _InkPainter(onPage, color),
        size: Size.infinite,
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes, this.color);

  final List<InkStroke> strokes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(
          stroke.points.first.x * size.width,
          stroke.points.first.y * size.height,
        );
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.x * size.width, point.y * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) =>
      oldDelegate.strokes != strokes || oldDelegate.color != color;
}
