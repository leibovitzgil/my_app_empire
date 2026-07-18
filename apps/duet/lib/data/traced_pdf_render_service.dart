import 'dart:async';
import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:duet/data/perf_tracer.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

/// A [PdfRenderService] decorator that records Firebase Performance traces
/// around the contract's two hot methods — [open] (`pdf_open`, attributes:
/// page count + byte-size bucket) and [renderPage] (`pdf_render_page`,
/// attribute: scale) — and delegates every other method
/// ([renderThumbnail], [checksum]) straight through (M7.3).
///
/// ## Zero critical-path cost (M7.3 step 4)
///
/// Tracing never adds synchronous work to a render. A trace is started
/// through the injected [PerfTracer] seam — a plain object construction, no
/// await — and both the attribute writes and the trace *stop* are issued
/// fire-and-forget AFTER the delegated future completes, so the value a
/// caller awaits is returned the instant the real work finishes. The
/// byte-size read for [open]'s bucket is kicked off concurrently with the
/// open (never before it), so it too stays off the critical path. When the
/// seam yields a null trace (the mock/emulator path binds [NoopPerfTracer],
/// which has no real Performance backend) each method is a pure
/// pass-through.
///
/// ## Firebase stays out (G2)
///
/// This decorator imports no Firebase package — it talks only to the
/// [PerfTracer] seam. That is what lets it be unit-tested with a fake
/// recorder and keeps `firebase_performance` off the headless gate.
class TracedPdfRenderService implements PdfRenderService {
  /// Wraps [delegate], routing traces through [tracer].
  TracedPdfRenderService({
    required PdfRenderService delegate,
    required PerfTracer tracer,
  }) : _delegate = delegate,
       _tracer = tracer;

  final PdfRenderService _delegate;
  final PerfTracer _tracer;

  @override
  Future<Result<int>> open(String path) async {
    final trace = _tracer.start('pdf_open');
    if (trace == null) return _delegate.open(path);
    // Kicked off concurrently with the (far slower) open, so awaiting it in
    // `_finishOpen` doesn't inflate the measured open duration.
    final sizeBucket = _byteSizeBucket(path);
    final result = await _delegate.open(path);
    unawaited(_finishOpen(trace, result, sizeBucket));
    return result;
  }

  Future<void> _finishOpen(
    PerfTrace trace,
    Result<int> result,
    Future<String> sizeBucket,
  ) async {
    if (result case Success<int>(:final value)) {
      trace.putAttribute('page_count', '$value');
    }
    trace
      ..putAttribute('byte_size_bucket', await sizeBucket)
      ..stop();
  }

  @override
  Future<Result<PdfPageImage>> renderPage(int pageIndex, {double scale = 1}) {
    final trace = _tracer.start('pdf_render_page');
    if (trace == null) {
      return _delegate.renderPage(pageIndex, scale: scale);
    }
    // Scale is known up front; the attribute write is synchronous.
    trace.putAttribute('scale', scale.toStringAsFixed(2));
    return _delegate.renderPage(pageIndex, scale: scale).then((result) {
      trace.stop();
      return result;
    });
  }

  @override
  Future<Result<PdfPageImage>> renderThumbnail(
    int pageIndex, {
    int maxWidth = 96,
  }) => _delegate.renderThumbnail(pageIndex, maxWidth: maxWidth);

  @override
  Future<Result<String>> checksum(String path) => _delegate.checksum(path);

  /// The byte-size bucket label for the file at [path], or `unknown` when its
  /// size can't be read. Coarse buckets keep the attribute low-cardinality
  /// (Performance groups traces by attribute value).
  Future<String> _byteSizeBucket(String path) async {
    try {
      return bucketForBytes(await File(path).length());
    } on Object {
      return 'unknown';
    }
  }

  /// Maps a raw [bytes] size onto a coarse bucket label. Exposed for tests.
  @visibleForTesting
  static String bucketForBytes(int bytes) {
    const mb = 1024 * 1024;
    if (bytes < mb) return '<1MB';
    if (bytes < 5 * mb) return '1-5MB';
    if (bytes < 20 * mb) return '5-20MB';
    if (bytes < 50 * mb) return '20-50MB';
    return '>=50MB';
  }
}
