import 'dart:math' as math;

/// The maximum number of pixels a single rendered full-page image may contain
/// (~16 MP). At 4 bytes/pixel (RGBA8888) a 16 MP page decodes to ~64 MB, so a
/// small LRU of these stays well inside a mobile memory budget. This is the
/// hard cap that render-scale-by-zoom is bounded against: no matter how far a
/// player zooms, one page can never be rendered larger than this.
const int maxPageImagePixels = 16 * 1000 * 1000;

/// Clamps [requestedScale] so the page ([pointWidth] × [pointHeight] points,
/// scaled) never renders to more than [maxPixels] pixels.
///
/// Returns [requestedScale] unchanged when the scaled page already fits the
/// budget; otherwise the largest scale that exactly fills it. Degenerate
/// inputs (non-positive dimensions or scale) pass through untouched so the
/// caller's own validation still runs.
double fittedRenderScale({
  required double requestedScale,
  required double pointWidth,
  required double pointHeight,
  int maxPixels = maxPageImagePixels,
}) {
  if (pointWidth <= 0 || pointHeight <= 0 || requestedScale <= 0) {
    return requestedScale;
  }
  final pixels = pointWidth * requestedScale * (pointHeight * requestedScale);
  if (pixels <= maxPixels) return requestedScale;
  return requestedScale * math.sqrt(maxPixels / pixels);
}
