import 'package:feature_score/src/ui/widgets/ink_palette.dart';
import 'package:flutter/material.dart';
import 'package:pieces/pieces.dart';

/// Paints [strokes] for a single ink layer on top of a rendered page.
///
/// Each [InkStroke.points] is fractional (0.0-1.0 of the page), so this
/// widget translates them into the actual size it's laid out at — it should
/// be sized to exactly match the rendered page (see `ScorePageCanvas`).
class InkOverlay extends StatelessWidget {
  /// Creates an [InkOverlay] for [strokes], drawing only those on
  /// [pageIndex].
  const InkOverlay({required this.strokes, required this.pageIndex, super.key});

  /// The layer's strokes, across all pages (filtered to [pageIndex] here).
  final List<InkStroke> strokes;

  /// The page currently shown.
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final onPage = strokes.where((s) => s.pageIndex == pageIndex).toList();
    return IgnorePointer(
      child: CustomPaint(painter: _InkPainter(onPage), size: Size.infinite),
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes);

  final List<InkStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = inkColorForId(stroke.colorId)
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
      oldDelegate.strokes != strokes;
}
