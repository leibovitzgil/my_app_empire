import 'package:duet/domain/domain.dart';
import 'package:duet/features/score/src/ui/widgets/region_highlight_overlay.dart';
import 'package:flutter/material.dart';

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
            // `primary` alone reads poorly against the light page paper
            // (~1.5:1 luminance contrast); the shared painter backs the
            // dashed accent with a dark halo so the design's primary-accent
            // selection stays legible on paper and veil alike.
            painter: RegionOverlayPainter(
              regionFor: (_) => _dragRect,
              strokeColor: scheme.primary,
              veilColor: scheme.scrim,
              repaintKey: _dragRect,
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
