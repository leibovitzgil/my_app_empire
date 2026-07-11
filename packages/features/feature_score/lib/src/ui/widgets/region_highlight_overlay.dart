import 'package:flutter/material.dart';
import 'package:pieces/pieces.dart';

/// A non-interactive spotlight on one fractional [region] of the page: dims
/// everything outside it and traces the region itself with a dashed border
/// and corner handles in [accentColor].
///
/// Sized to exactly match the rendered page (an entry in
/// `ScorePageCanvas.overlays`), so the highlight pans/zooms with the sheet.
/// Shared by the passage popover (the selection must stay visible while the
/// user decides what to do with it) and the record-note flow (the passage
/// being talked about stays spotlit while the card is up).
class RegionHighlightOverlay extends StatelessWidget {
  /// Creates a [RegionHighlightOverlay] for [region].
  const RegionHighlightOverlay({
    required this.region,
    required this.accentColor,
    super.key,
  });

  /// The fractional page region to keep bright.
  final Region region;

  /// The border/handle colour (e.g. the theme error colour while recording,
  /// primary while reviewing/selecting).
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final scrim = Theme.of(context).colorScheme.scrim;
    return IgnorePointer(
      child: CustomPaint(
        painter: RegionOverlayPainter(
          regionFor: (size) => Rect.fromLTWH(
            region.left * size.width,
            region.top * size.height,
            region.width * size.width,
            region.height * size.height,
          ),
          strokeColor: accentColor,
          veilColor: scrim,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Paints the region-select treatment — an outside-the-rect veil, a dashed
/// border, and square corner handles — for whatever rect [regionFor] resolves
/// at paint time.
///
/// Shared by [RegionHighlightOverlay] (a fixed fractional region) and
/// `RegionSelector` (the live drag rect), so a completed selection looks
/// exactly like the drag that produced it.
class RegionOverlayPainter extends CustomPainter {
  /// Creates a [RegionOverlayPainter].
  RegionOverlayPainter({
    required this.regionFor,
    required this.strokeColor,
    required this.veilColor,
    this.repaintKey,
  });

  /// Resolves the pixel rect to highlight for the painted [Size]; `null`
  /// paints nothing.
  final Rect? Function(Size size) regionFor;

  /// The dashed border/handle colour.
  final Color strokeColor;

  /// The colour dimming everything outside the rect (alpha applied here).
  final Color veilColor;

  /// Equality key for [shouldRepaint] — callers pass whatever value the
  /// resolved rect depends on (e.g. the drag rect itself).
  final Object? repaintKey;

  static const double _dashWidth = 6;
  static const double _dashGap = 4;
  static const double _handleSize = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = regionFor(size);
    if (rect == null) return;

    // Dims everything outside the rect via an even-odd fill, so the rect
    // itself is left as a "hole" showing the page at full brightness.
    final veilPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(
      veilPath,
      Paint()..color = veilColor.withValues(alpha: 0.35),
    );

    // A hairline halo just outside the dashed stroke keeps the accent legible
    // where it crosses the un-dimmed page paper (light accents like the dark
    // theme's primary sit at ~1.5:1 against paper on their own).
    final haloPaint = Paint()
      ..color = veilColor.withValues(alpha: 0.55)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    _drawDashedRect(canvas, rect, haloPaint);

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
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: corner,
            width: _handleSize,
            height: _handleSize,
          ),
          const Radius.circular(2),
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
  bool shouldRepaint(covariant RegionOverlayPainter oldDelegate) =>
      oldDelegate.repaintKey != repaintKey ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.veilColor != veilColor;
}
