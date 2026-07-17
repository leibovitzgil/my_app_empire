import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core_utils/core_utils.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

/// An LRU cache of decoded page thumbnails for the reader's page rail.
///
/// Entries are keyed by `(checksum, pageIndex)` — the piece PDF's content
/// checksum, exactly as `PdfRenderService.checksum`'s doc anticipates for
/// cached renders — so a re-imported or drifted copy of the same piece never
/// serves stale pages. The cache holds at most [capacity] decoded images
/// (a 60-page scan can't accumulate unbounded `ui.Image`s) and disposes
/// evicted ones.
///
/// Ownership: [thumbnail] returns a *clone* the caller owns and must
/// dispose. The cache disposes only its own handle (on eviction and
/// [dispose]), so evicting an entry can never invalidate an image a widget
/// is still drawing.
class ThumbnailCache {
  /// Creates a [ThumbnailCache] over [renderService], which must already be
  /// `open()`ed on the piece's PDF before [thumbnail] is called.
  ThumbnailCache({
    required PdfRenderService renderService,
    this.capacity = 40,
    this.maxWidth = 96,
  }) : _renderService = renderService;

  final PdfRenderService _renderService;

  /// The maximum number of decoded thumbnails kept alive.
  final int capacity;

  /// The pixel width thumbnails are rendered at (see
  /// `PdfRenderService.renderThumbnail`).
  final int maxWidth;

  /// Insertion-ordered: first entry = least recently used.
  final Map<String, ui.Image> _images = <String, ui.Image>{};

  /// In-flight renders, so concurrent requests for one page share a render.
  final Map<String, Future<void>> _pending = <String, Future<void>>{};

  bool _disposed = false;

  /// The number of decoded thumbnails currently cached.
  int get length => _images.length;

  /// Resolves the thumbnail for ([checksum], [pageIndex]), rendering and
  /// decoding it on a miss. Returns a clone the caller must dispose, or
  /// `null` if the render failed (callers keep their placeholder; a later
  /// request retries — failures are never cached).
  Future<ui.Image?> thumbnail({
    required String checksum,
    required int pageIndex,
  }) async {
    if (_disposed) return null;
    final key = '$checksum#$pageIndex';
    final hit = _images.remove(key);
    if (hit != null) {
      // Re-insert to mark most recently used.
      _images[key] = hit;
      return hit.clone();
    }
    await (_pending[key] ??= _load(key, pageIndex));
    if (_disposed) return null;
    final loaded = _images.remove(key);
    if (loaded == null) return null;
    _images[key] = loaded;
    return loaded.clone();
  }

  Future<void> _load(String key, int pageIndex) async {
    try {
      final result = await _renderService.renderThumbnail(
        pageIndex,
        maxWidth: maxWidth,
      );
      if (result case Success<PdfPageImage>(:final value)) {
        final image = await _decode(value);
        if (_disposed) {
          image.dispose();
          return;
        }
        _images[key] = image;
        _evictOverCapacity();
      }
    } on Object catch (_) {
      // A failed render (including a service that threw instead of returning
      // a ResultFailure) just leaves no entry: the caller shows its
      // placeholder and a later request retries.
    } finally {
      final _ = _pending.remove(key);
    }
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

  void _evictOverCapacity() {
    while (_images.length > capacity) {
      final oldest = _images.keys.first;
      _images.remove(oldest)?.dispose();
    }
  }

  /// Disposes every cached image. Requests after this resolve to `null`.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
  }
}
