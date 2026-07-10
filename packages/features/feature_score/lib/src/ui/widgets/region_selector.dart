import 'package:flutter/material.dart';
import 'package:pieces/pieces.dart';

/// Drag-a-rectangle gesture handler, active only while `ScoreMode` is
/// `regionSelect`.
///
/// While dragging, a live dashed rectangle with corner handles previews the
/// selection against a dimmed veil (purely local widget state — a snappy
/// 60fps drag shouldn't round-trip through the bloc for every pixel of
/// movement, though [onRegionPreview] still mirrors it into
/// `ScoreState.activeRegion` per frame for other listeners). On release, if
/// the drag cleared the minimum size, [onRegionCompleted] fires with the
/// final fractional [Region] — the caller (`score_viewer_screen.dart`)
/// decides what UI (an anchored popover or a bottom sheet) offers "Practice"
/// / "Record" / "Cancel" from there; this widget no longer makes that
/// choice itself.
class RegionSelector extends StatefulWidget {
  /// Creates a [RegionSelector] for [pageIndex].
  const RegionSelector({
    required this.pageIndex,
    required this.onRegionPreview,
    required this.onRegionCompleted,
    super.key,
  });

  /// The page being selected on.
  final int pageIndex;

  /// Called with a fractional [Region] on every drag update, for live
  /// preview via bloc state.
  final ValueChanged<Region> onRegionPreview;

  /// Called once a final region has been dragged out (and cleared the
  /// minimum drag size).
  final ValueChanged<Region> onRegionCompleted;

  @override
  State<RegionSelector> createState() => _RegionSelectorState();
}

class _RegionSelectorState extends State<RegionSelector> {
  Offset? _start;
  Offset? _current;

  static const double _minDragPixels = 24;

  Rect? get _dragRect {
    final start = _start;
    final current = _current;
    if (start == null || current == null) return null;
    return Rect.fromPoints(start, current);
  }

  Region _toRegion(Rect rect, Size size) {
    return Region(
      pageIndex: widget.pageIndex,
      left: (rect.left / size.width).clamp(0, 1),
      top: (rect.top / size.height).clamp(0, 1),
      width: (rect.width / size.width).clamp(0, 1),
      height: (rect.height / size.height).clamp(0, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            setState(() {
              _start = details.localPosition;
              _current = details.localPosition;
            });
          },
          onPanUpdate: (details) {
            setState(() => _current = details.localPosition);
            final rect = _dragRect;
            if (rect != null && size.width > 0 && size.height > 0) {
              widget.onRegionPreview(_toRegion(rect, size));
            }
          },
          onPanEnd: (_) => _finishDrag(size),
          child: CustomPaint(
            // The dashed rect/handles read poorly in `colorScheme.primary`
            // against the light page paper in this app's dark theme
            // (verified: ~1.5:1 luminance contrast) — `onPrimary` is the
            // pairing Material designed for exactly this "reads against a
            // light surface" need, so it's used here instead while staying
            // a themed role rather than a new hardcoded literal.
            painter: _RegionPainter(
              _dragRect,
              strokeColor: scheme.onPrimary,
              veilColor: scheme.scrim,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  void _finishDrag(Size size) {
    final rect = _dragRect;
    setState(() {
      _start = null;
      _current = null;
    });
    if (rect == null ||
        size.width <= 0 ||
        size.height <= 0 ||
        rect.width < _minDragPixels ||
        rect.height < _minDragPixels) {
      return;
    }
    widget.onRegionCompleted(_toRegion(rect, size));
  }
}

class _RegionPainter extends CustomPainter {
  _RegionPainter(
    this.rect, {
    required this.strokeColor,
    required this.veilColor,
  });

  final Rect? rect;
  final Color strokeColor;
  final Color veilColor;

  static const double _dashWidth = 6;
  static const double _dashGap = 4;
  static const double _handleSize = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = this.rect;
    if (rect == null) return;

    // Dims everything outside the dragged rect via an even-odd fill, so the
    // rect itself is left as a "hole" showing the page at full brightness.
    final veilPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(
      veilPath,
      Paint()..color = veilColor.withValues(alpha: 0.35),
    );

    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    _drawDashedRect(canvas, rect, paint);

    final handlePaint = Paint()..color = strokeColor;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: corner,
          width: _handleSize,
          height: _handleSize,
        ),
        handlePaint,
      );
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    final path = Path()..addRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + _dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += _dashWidth + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RegionPainter oldDelegate) =>
      oldDelegate.rect != rect ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.veilColor != veilColor;
}
