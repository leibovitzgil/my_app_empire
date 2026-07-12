import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
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
/// [renderService] must already be `open`ed on the piece's PDF by the
/// caller — this widget only calls [PdfRenderService.renderPage].
class ScorePageCanvas extends StatefulWidget {
  /// Creates a [ScorePageCanvas] for [pageIndex].
  const ScorePageCanvas({
    required this.renderService,
    required this.pageIndex,
    this.overlays = const [],
    this.focusRegion,
    this.scale = 2,
    this.boundaryMargin = const EdgeInsets.all(64),
    super.key,
  });

  /// The already-opened PDF render service.
  final PdfRenderService renderService;

  /// The zero-based page to render.
  final int pageIndex;

  /// Widgets stacked on top of the rendered page, in the same 0.0-1.0
  /// fractional coordinate space (e.g. via `Align`).
  final List<Widget> overlays;

  /// If set, the view centers and zooms to this region once the page has
  /// rendered (used by the practice view). The first focus lands instantly;
  /// later changes (stepping between passages) glide there, so the player
  /// keeps their bearings on the page.
  final Region? focusRegion;

  /// The render scale factor (higher = sharper, more memory).
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
  late Future<ui.Image> _imageFuture;
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
    _imageFuture = _renderPage();
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
    if (oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.renderService != widget.renderService) {
      _focusedRegion = null;
      setState(() {
        _imageFuture = _renderPage();
      });
    }
  }

  @override
  void dispose() {
    _focusController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<ui.Image> _renderPage() async {
    final result = await widget.renderService.renderPage(
      widget.pageIndex,
      scale: widget.scale,
    );
    return switch (result) {
      Success<PdfPageImage>(:final value) => _decode(value),
      ResultFailure<PdfPageImage>(:final error) => Future.error(error),
    };
  }

  Future<ui.Image> _decode(PdfPageImage page) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      Uint8List.fromList(page.bytes),
      page.width,
      page.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
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
    return FutureBuilder<ui.Image>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(label: 'Rendering page…');
        }
        if (snapshot.hasError) {
          return ErrorRetryView(
            title: "Couldn't render this page",
            message: '${snapshot.error}',
            onRetry: () => setState(() {
              _imageFuture = _renderPage();
            }),
          );
        }
        final image = snapshot.data!;
        final scheme = Theme.of(context).colorScheme;
        return LayoutBuilder(
          builder: (context, constraints) {
            final viewportSize = constraints.biggest;
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
      },
    );
  }
}
