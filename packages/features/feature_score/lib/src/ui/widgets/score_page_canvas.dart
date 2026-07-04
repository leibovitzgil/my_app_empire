import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';

/// Renders a single PDF page (via [PdfRenderService]) with pan/zoom, hosting
/// [overlays] (ink layers, audio pins, the region selector) as children
/// positioned in the same fractional coordinate space as the page image.
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
  /// rendered (used by the practice view).
  final Region? focusRegion;

  /// The render scale factor (higher = sharper, more memory).
  final double scale;

  @override
  State<ScorePageCanvas> createState() => _ScorePageCanvasState();
}

class _ScorePageCanvasState extends State<ScorePageCanvas> {
  late Future<ui.Image> _imageFuture;
  final _transformationController = TransformationController();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _imageFuture = _renderPage();
  }

  @override
  void didUpdateWidget(covariant ScorePageCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.renderService != widget.renderService) {
      _focused = false;
      setState(() => _imageFuture = _renderPage());
    }
  }

  @override
  void dispose() {
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

  void _focusOnRegionIfNeeded(Size viewportSize) {
    final region = widget.focusRegion;
    if (_focused || region == null || viewportSize.isEmpty) return;
    _focused = true;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _transformationController.value = Matrix4.identity()
        ..translateByDouble(dx, dy, 0, 1)
        ..scaleByDouble(scale, scale, scale, 1);
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
            onRetry: () => setState(() => _imageFuture = _renderPage()),
          );
        }
        final image = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final viewportSize = constraints.biggest;
            _focusOnRegionIfNeeded(viewportSize);
            return InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 6,
              child: AspectRatio(
                aspectRatio: image.width / image.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RawImage(image: image, fit: BoxFit.contain),
                    ...widget.overlays,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
