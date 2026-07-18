import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:core_ui/core_ui.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/score/src/page_image_cache.dart';
import 'package:flutter/material.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

/// Renders a single PDF page (via [PdfRenderService]) with pan/zoom, hosting
/// [overlays] (ink layers, audio pins, the region selector) as children
/// positioned in the same fractional coordinate space as the page image.
///
/// The page floats on the reader's dark stage — rounded corners and a soft
/// shadow travel with it under pan/zoom, matching the design's paper-on-
/// stage look.
///
/// **Memory & sharpness (M8.2).** Pages are decoded through a [PageImageCache]
/// (owned per canvas, so it survives page flips) rather than one-off futures:
/// the current page and its two neighbours are kept warm and everything older
/// is evicted and disposed, so flipping through a 60-page scan never grows
/// unbounded. The base render scale is fitted to the viewport (not a fixed
/// 2×), and zooming in past ~1.5× re-renders the page sharper (debounced,
/// swapped in place) up to the render service's ≤16 MP-per-page budget.
///
/// [renderService] must already be `open`ed on the piece's PDF by the
/// caller — this widget only calls [PdfRenderService.renderPage].
class ScorePageCanvas extends StatefulWidget {
  /// Creates a [ScorePageCanvas] for [pageIndex].
  const ScorePageCanvas({
    required this.renderService,
    required this.checksum,
    required this.pageIndex,
    required this.pageCount,
    this.overlays = const [],
    this.focusRegion,
    this.scale = 2,
    this.boundaryMargin = const EdgeInsets.all(64),
    super.key,
  });

  /// The already-opened PDF render service.
  final PdfRenderService renderService;

  /// The piece PDF's content checksum, keying cached page renders (see
  /// [PageImageCache]) so a drifted or re-imported copy never serves a stale
  /// page. May be empty when a piece has no checksum yet — it still keys
  /// consistently within one open document.
  final String checksum;

  /// The zero-based page to render.
  final int pageIndex;

  /// The document's total page count, bounding neighbour prefetch.
  final int pageCount;

  /// Widgets stacked on top of the rendered page, in the same 0.0-1.0
  /// fractional coordinate space (e.g. via `Align`).
  final List<Widget> overlays;

  /// If set, the view centers and zooms to this region once the page has
  /// rendered (used by the practice view). The first focus lands instantly;
  /// later changes (stepping between passages) glide there, so the player
  /// keeps their bearings on the page.
  final Region? focusRegion;

  /// A fallback render scale, used only until the viewport is known (the base
  /// scale is otherwise fitted to the viewport).
  final double scale;

  /// How far a gesture may pan the page past its own edges. The reader's
  /// default is a small nudge (the fit-zoomed page shouldn't wander); the
  /// practice view passes a much larger margin so a zoomed-in passage near
  /// the page edge can still sit centred without the next gesture snapping
  /// the view back inside tight bounds.
  final EdgeInsets boundaryMargin;

  @override
  State<ScorePageCanvas> createState() => _ScorePageCanvasState();
}

class _ScorePageCanvasState extends State<ScorePageCanvas>
    with SingleTickerProviderStateMixin {
  /// Zoom (relative to the base render) past which the page is re-rendered
  /// sharper — below this the base image upscales acceptably.
  static const double _zoomUpgradeThreshold = 1.5;

  /// A representative sheet-music page's long edge, in PDF points (~US Letter/
  /// A4 portrait). Used to turn the viewport's pixel size into a
  /// point-relative render scale without a separate page-measure round-trip;
  /// the render service's ≤16 MP budget is the true ceiling, so an off
  /// estimate only costs a little sharpness, never memory.
  static const double _referencePageLongEdgePts = 1000;
  static const double _minBaseScale = 1;
  static const double _maxBaseScale = 3;

  /// The debounce before a zoom settles into a sharper re-render, so a pinch
  /// gesture fires one render at the end rather than dozens mid-flight.
  static const Duration _zoomRerenderDebounce = Duration(milliseconds: 250);

  late PageImageCache _pageCache;

  /// The decoded page currently drawn — a clone this state owns and disposes.
  ui.Image? _image;
  Object? _error;
  bool _loading = false;

  /// The scale [_image] was rendered at, and the viewport-fitted base scale.
  double _renderedScale = 0;
  late double _baseScale = widget.scale;

  /// Bumped on every (re)load so a stale async render resolving late is
  /// dropped instead of overwriting a newer page.
  int _loadGeneration = 0;

  Timer? _zoomDebounce;

  final _transformationController = TransformationController();
  late final AnimationController _focusController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  Animation<Matrix4>? _focusAnimation;
  Region? _focusedRegion;

  @override
  void initState() {
    super.initState();
    _pageCache = PageImageCache(renderService: widget.renderService);
    _transformationController.addListener(_onZoomChanged);
    _focusController.addListener(() {
      final animation = _focusAnimation;
      if (animation != null) {
        _transformationController.value = animation.value;
      }
    });
  }

  @override
  void didUpdateWidget(covariant ScorePageCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final serviceChanged = oldWidget.renderService != widget.renderService;
    if (serviceChanged) {
      // A new document: throw away the old page cache (and its images) and
      // render into a fresh one.
      _pageCache.dispose();
      _pageCache = PageImageCache(renderService: widget.renderService);
    }
    if (serviceChanged ||
        oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.checksum != widget.checksum) {
      _focusedRegion = null;
      _zoomDebounce?.cancel();
      unawaited(_loadPage());
    }
  }

  @override
  void dispose() {
    _zoomDebounce?.cancel();
    _focusController.dispose();
    _transformationController.dispose();
    _image?.dispose();
    _pageCache.dispose();
    super.dispose();
  }

  /// Point-relative base scale that fits the page to [viewport] at the
  /// device's pixel density, clamped to a sane range (the ≤16 MP budget is
  /// enforced downstream in the render service).
  double _baseScaleFor(Size viewport, double devicePixelRatio) {
    if (viewport.isEmpty) return widget.scale;
    final longestLogical = math.max(viewport.width, viewport.height);
    final target =
        longestLogical * devicePixelRatio / _referencePageLongEdgePts;
    return target.clamp(_minBaseScale, _maxBaseScale);
  }

  /// Reconciles the base scale with the current viewport, kicking off the
  /// first render and (rarely, e.g. on rotation to a larger viewport) a
  /// sharper re-render. Called from `build`; any load is deferred to a
  /// microtask so it never calls `setState` during layout.
  void _syncViewport(Size viewport, double devicePixelRatio) {
    if (viewport.isEmpty) return;
    final base = _baseScaleFor(viewport, devicePixelRatio);
    final needInitial = _image == null && _error == null && !_loading;
    final wantSharperBase =
        _image != null && !_loading && base > _renderedScale * 1.25;
    _baseScale = base;
    if (needInitial) {
      _loading = true;
      scheduleMicrotask(_loadPage);
    } else if (wantSharperBase) {
      scheduleMicrotask(() => _render(scale: base, keepCurrent: true));
    }
  }

  /// Loads the current page at the base scale, blanking to a loading state
  /// first (a page flip should read as "rendering", not a frozen old page),
  /// then warms the neighbours.
  Future<void> _loadPage() async {
    if (!mounted) return;
    setState(() {
      _image?.dispose();
      _image = null;
      _error = null;
      _renderedScale = 0;
      _loading = true;
    });
    await _render(scale: _baseScale, keepCurrent: false);
    if (mounted) _schedulePrefetch();
  }

  /// Renders the current page at [scale] and swaps it in. When [keepCurrent]
  /// is true (a zoom-driven sharpening) the existing image stays on screen
  /// until the sharper one is ready, and a failed render is swallowed rather
  /// than replacing good pixels with an error.
  Future<void> _render({
    required double scale,
    required bool keepCurrent,
  }) async {
    final generation = ++_loadGeneration;
    final image = await _pageCache.page(
      checksum: widget.checksum,
      pageIndex: widget.pageIndex,
      scale: scale,
    );
    if (!mounted || generation != _loadGeneration) {
      image?.dispose();
      return;
    }
    setState(() {
      _loading = false;
      if (image == null) {
        if (!keepCurrent) _error = 'Could not render this page';
      } else {
        _image?.dispose();
        _image = image;
        _renderedScale = scale;
        _error = null;
      }
    });
  }

  /// After a zoom gesture settles, re-renders the page sharper if the user is
  /// zoomed in far enough that the base render would look soft — debounced,
  /// capped so we never ask for more than the budget allows.
  void _onZoomChanged() {
    if (_image == null) return;
    final zoom = _transformationController.value.getMaxScaleOnAxis();
    if (zoom <= _zoomUpgradeThreshold) return;
    // Target the on-screen zoom, capped at 6× base (the InteractiveViewer's
    // own max); the render service clamps the absolute pixel budget.
    final target = (_baseScale * zoom).clamp(_baseScale, _baseScale * 6);
    if (target <= _renderedScale * 1.01) return;
    _zoomDebounce?.cancel();
    _zoomDebounce = Timer(_zoomRerenderDebounce, () {
      if (!mounted) return;
      unawaited(_render(scale: target, keepCurrent: true));
    });
  }

  /// Warms the previous/next page at the base scale so a flip is instant.
  /// Runs post-frame and re-checks the page hasn't changed underneath it, so
  /// flipping quickly cancels stale prefetches instead of thrashing the cache.
  void _schedulePrefetch() {
    final page = widget.pageIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final neighbour in [page - 1, page + 1]) {
        if (!mounted || widget.pageIndex != page) return;
        if (neighbour < 0 || neighbour >= widget.pageCount) continue;
        final warmed = await _pageCache.page(
          checksum: widget.checksum,
          pageIndex: neighbour,
          scale: _baseScale,
        );
        // The cache keeps its own copy; we only warmed it, so drop the clone.
        warmed?.dispose();
      }
    });
  }

  Matrix4 _matrixForRegion(Region region, Size viewportSize) {
    final scale = math
        .min(
          math.min(
            1 / math.max(region.width, 0.05),
            1 / math.max(region.height, 0.05),
          ),
          5,
        )
        .toDouble();
    final centerX = (region.left + region.width / 2) * viewportSize.width;
    final centerY = (region.top + region.height / 2) * viewportSize.height;
    final dx = viewportSize.width / 2 - centerX * scale;
    final dy = viewportSize.height / 2 - centerY * scale;
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _focusOnRegionIfNeeded(Size viewportSize) {
    final region = widget.focusRegion;
    if (region == null || region == _focusedRegion || viewportSize.isEmpty) {
      return;
    }
    // The first focus (opening the practice view) lands instantly; moving
    // between passages glides, so the jump reads as motion across the page
    // rather than a cut.
    final animate = _focusedRegion != null;
    _focusedRegion = region;
    final target = _matrixForRegion(region, viewportSize);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!animate) {
        _transformationController.value = target;
        return;
      }
      _focusAnimation =
          Matrix4Tween(
                begin: _transformationController.value,
                end: target,
              )
              .chain(CurveTween(curve: Curves.easeInOutCubic))
              .animate(
                _focusController,
              );
      unawaited(_focusController.forward(from: 0));
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = constraints.biggest;
        _syncViewport(viewportSize, MediaQuery.devicePixelRatioOf(context));
        if (_error != null) {
          return ErrorRetryView(
            title: "Couldn't render this page",
            message: '$_error',
            onRetry: () {
              setState(() {
                _error = null;
                _loading = true;
              });
              unawaited(_loadPage());
            },
          );
        }
        final image = _image;
        if (image == null) {
          return const LoadingView(label: 'Rendering page…');
        }
        _focusOnRegionIfNeeded(viewportSize);
        return InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 6,
          boundaryMargin: widget.boundaryMargin,
          child: AspectRatio(
            aspectRatio: image.width / image.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.5),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RawImage(image: image, fit: BoxFit.contain),
                    ...widget.overlays,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
