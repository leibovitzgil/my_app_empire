import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core_utils/core_utils.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

/// One cached full-page render: the decoded image plus the scale it was
/// rendered at, so a later request for a *sharper* image (zoomed in) can tell
/// the cached copy is too coarse and re-render, while a request for the same
/// or lower scale is served straight from memory.
class _CachedPage {
  _CachedPage(this.image, this.scale);

  final ui.Image image;
  final double scale;
}

/// An LRU cache of decoded full-page images for the score reader's main
/// canvas — the large sibling of `ThumbnailCache`, sized for the *full-page*
/// renders `ScorePageCanvas` draws rather than the rail's tiny previews.
///
/// A 60-page scan can't accumulate 60 decoded full pages: the cache holds at
/// most [capacity] (default 3 — the current page plus its two neighbours,
/// which the reader keeps warm) and disposes evicted `ui.Image`s. Combined
/// with the render service's ≤16 MP-per-page budget (see [fittedRenderScale]),
/// decoded page memory stays bounded regardless of document length or zoom.
///
/// Entries are keyed by `(checksum, pageIndex)` — the piece PDF's content
/// checksum, mirroring `ThumbnailCache` — so a re-imported or drifted copy of
/// the same piece never serves a stale page.
///
/// Ownership: [page] returns a *clone* the caller owns and must dispose. The
/// cache disposes only its own handle (on eviction, on a sharper re-render,
/// and on [dispose]), so evicting or upgrading an entry can never invalidate
/// an image a widget is still drawing.
class PageImageCache {
  /// Creates a [PageImageCache] over [renderService], which must already be
  /// `open()`ed on the piece's PDF before [page] is called.
  PageImageCache({
    required PdfRenderService renderService,
    this.capacity = 3,
  }) : _renderService = renderService;

  final PdfRenderService _renderService;

  /// The maximum number of decoded full-page images kept alive.
  final int capacity;

  /// Scales within this epsilon are treated as equal, so floating-point
  /// jitter in a computed base scale doesn't force a needless re-render.
  static const double _scaleEpsilon = 0.01;

  /// Insertion-ordered: first entry = least recently used.
  final Map<String, _CachedPage> _pages = <String, _CachedPage>{};

  /// In-flight renders, so concurrent requests for one page share a render.
  /// The recorded scale lets a request for a *sharper* image than the one
  /// being rendered start its own higher-scale render instead of waiting for
  /// a copy it already knows is too coarse.
  final Map<String, ({Future<void> future, double scale})> _pending =
      <String, ({Future<void> future, double scale})>{};

  bool _disposed = false;

  /// The number of decoded full-page images currently cached.
  int get length => _pages.length;

  /// Resolves the image for ([checksum], [pageIndex]) at least as sharp as
  /// [scale] (page points × scale), rendering on a miss or when the cached
  /// copy is coarser. Returns a clone the caller must dispose, or `null` if
  /// the render failed (callers keep a placeholder; a later request retries —
  /// failures are never cached).
  Future<ui.Image?> page({
    required String checksum,
    required int pageIndex,
    required double scale,
  }) async {
    if (_disposed) return null;
    final key = '$checksum#$pageIndex';
    final hit = _pages[key];
    if (hit != null && hit.scale >= scale - _scaleEpsilon) {
      _touch(key);
      return hit.image.clone();
    }
    final pending = _pending[key];
    final Future<void> load;
    if (pending != null && pending.scale >= scale - _scaleEpsilon) {
      // An in-flight render is already at least this sharp — ride it.
      load = pending.future;
    } else {
      load = _load(key, pageIndex, scale);
      _pending[key] = (future: load, scale: scale);
    }
    await load;
    if (_disposed) return null;
    final loaded = _pages[key];
    if (loaded == null) return null;
    _touch(key);
    return loaded.image.clone();
  }

  Future<void> _load(String key, int pageIndex, double scale) async {
    try {
      final result = await _renderService.renderPage(pageIndex, scale: scale);
      if (result case Success<PdfPageImage>(:final value)) {
        final image = await _decode(value);
        if (_disposed) {
          image.dispose();
          return;
        }
        final existing = _pages[key];
        if (existing != null && existing.scale > scale + _scaleEpsilon) {
          // A sharper image is already cached (a concurrent higher-scale
          // render won): keep it, drop this coarser one.
          image.dispose();
          return;
        }
        _pages.remove(key)?.image.dispose();
        _pages[key] = _CachedPage(image, scale);
        _evictOverCapacity();
      }
    } on Object catch (_) {
      // A failed render leaves no entry: the caller shows its placeholder and
      // a later request retries.
    } finally {
      final registered = _pending[key];
      if (registered != null &&
          (registered.scale - scale).abs() < _scaleEpsilon) {
        final _ = _pending.remove(key);
      }
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

  /// Moves [key] to the most-recently-used end of the insertion order.
  void _touch(String key) {
    final entry = _pages.remove(key);
    if (entry != null) _pages[key] = entry;
  }

  void _evictOverCapacity() {
    while (_pages.length > capacity) {
      final oldest = _pages.keys.first;
      _pages.remove(oldest)?.image.dispose();
    }
  }

  /// Disposes every cached image. Requests after this resolve to `null`.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final entry in _pages.values) {
      entry.image.dispose();
    }
    _pages.clear();
  }
}
