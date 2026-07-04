import 'package:core_ui/core_ui.dart';
import 'package:feature_score/src/bloc/score_bloc.dart';
import 'package:flutter/material.dart';
import 'package:pieces/pieces.dart';

/// Drag-a-rectangle gesture handler, active only while `ScoreMode` is
/// `regionSelect`.
///
/// While dragging, a live dashed rectangle with corner handles previews the
/// selection (purely local widget state — a snappy 60fps drag shouldn't
/// round-trip through the bloc for every pixel of movement, though
/// [onRegionPreview] still mirrors it into `ScoreState.activeRegion` per
/// frame for other listeners). On release, an [AppBottomSheet] offers
/// "Record audio note" / "Practice this passage" / "Cancel"; picking one
/// calls [onRegionChosen] with the intent, which the caller uses to
/// dispatch both `RegionSelectStarted` and `RegionSelectCompleted`.
class RegionSelector extends StatefulWidget {
  /// Creates a [RegionSelector] for [pageIndex].
  const RegionSelector({
    required this.pageIndex,
    required this.onRegionPreview,
    required this.onRegionChosen,
    super.key,
  });

  /// The page being selected on.
  final int pageIndex;

  /// Called with a fractional [Region] on every drag update, for live
  /// preview via bloc state.
  final ValueChanged<Region> onRegionPreview;

  /// Called once a final region has been dragged out and the user picked an
  /// intent from the choice sheet.
  final void Function(Region region, RegionIntent intent) onRegionChosen;

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
            painter: _DashedRectPainter(_dragRect),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  Future<void> _finishDrag(Size size) async {
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
    final region = _toRegion(rect, size);
    final intent = await _chooseIntent();
    if (intent != null) widget.onRegionChosen(region, intent);
  }

  Future<RegionIntent?> _chooseIntent() {
    return AppBottomSheet.show<RegionIntent>(
      context,
      title: 'This passage',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Record an audio note for this passage',
            child: ListTile(
              leading: const Icon(Icons.mic_none_outlined),
              title: const Text('Record audio note'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(RegionIntent.recordAudio),
            ),
          ),
          Semantics(
            button: true,
            label: 'Practice this passage',
            child: ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Practice this passage'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(RegionIntent.practice),
            ),
          ),
          Semantics(
            button: true,
            label: 'Cancel region selection',
            child: ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter(this.rect);

  final Rect? rect;

  static const double _dashWidth = 6;
  static const double _dashGap = 4;
  static const double _handleSize = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = this.rect;
    if (rect == null) return;
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    _drawDashedRect(canvas, rect, paint);

    final handlePaint = Paint()..color = Colors.blueAccent;
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
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.rect != rect;
}
