import 'dart:async';
import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:duet/data/perf_tracer.dart';
import 'package:duet/data/traced_pdf_render_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

void main() {
  late _FakePdfRenderService delegate;
  late _RecordingPerfTracer tracer;
  late TracedPdfRenderService service;

  setUp(() {
    delegate = _FakePdfRenderService();
    tracer = _RecordingPerfTracer();
    service = TracedPdfRenderService(delegate: delegate, tracer: tracer);
  });

  group('open', () {
    test(
      'delegates to the wrapped service and returns its exact result',
      () async {
        final path = await _tempPdf(bytes: 128);
        delegate.openResult = const Success<int>(7);

        final result = await service.open(path.path);

        expect(result, delegate.openResult);
        expect(delegate.calls, ['open:${path.path}']);
      },
    );

    test(
      'starts a pdf_open trace, records page count + byte-size bucket, and '
      'stops it — all after the delegated future resolves',
      () async {
        final path = await _tempPdf(bytes: 128); // < 1 MB
        delegate.openResult = const Success<int>(7);

        await service.open(path.path);
        // The attribute writes + stop are fire-and-forget; wait for the stop.
        await tracer.traces.single.onStopped;

        expect(tracer.started, ['pdf_open']);
        final trace = tracer.traces.single;
        expect(trace.attributes['page_count'], '7');
        expect(trace.attributes['byte_size_bucket'], '<1MB');
        expect(trace.stopped, isTrue);
      },
    );

    test(
      'records byte-size bucket even when open fails (no page count)',
      () async {
        final path = await _tempPdf(bytes: 128);
        delegate.openResult = const ResultFailure<int>('boom');

        await service.open(path.path);
        await tracer.traces.single.onStopped;

        final trace = tracer.traces.single;
        expect(trace.attributes.containsKey('page_count'), isFalse);
        expect(trace.attributes['byte_size_bucket'], '<1MB');
        expect(trace.stopped, isTrue);
      },
    );
  });

  group('renderPage', () {
    test(
      'delegates (with scale) and returns the wrapped result',
      () async {
        delegate.renderResult = const Success<PdfPageImage>(_anyImage);

        final result = await service.renderPage(3, scale: 2.5);

        expect(result, delegate.renderResult);
        expect(delegate.calls, ['renderPage:3:2.5']);
      },
    );

    test(
      'starts a pdf_render_page trace with the scale attribute and stops it',
      () async {
        await service.renderPage(1, scale: 1.5);
        await tracer.traces.single.onStopped;

        expect(tracer.started, ['pdf_render_page']);
        final trace = tracer.traces.single;
        expect(trace.attributes['scale'], '1.50');
        expect(trace.stopped, isTrue);
      },
    );
  });

  group('pass-through methods are never traced', () {
    test('renderThumbnail delegates and starts no trace', () async {
      delegate.thumbnailResult = const Success<PdfPageImage>(_anyImage);

      final result = await service.renderThumbnail(4, maxWidth: 48);

      expect(result, delegate.thumbnailResult);
      expect(delegate.calls, ['renderThumbnail:4:48']);
      expect(tracer.started, isEmpty);
    });

    test('checksum delegates and starts no trace', () async {
      delegate.checksumResult = const Success<String>('deadbeef');

      final result = await service.checksum('/some/path.pdf');

      expect(result, delegate.checksumResult);
      expect(delegate.calls, ['checksum:/some/path.pdf']);
      expect(tracer.started, isEmpty);
    });
  });

  group('with a tracer that never traces (NoopPerfTracer-like)', () {
    setUp(() {
      service = TracedPdfRenderService(
        delegate: delegate,
        tracer: NoopPerfTracer(),
      );
    });

    test('open is a pure pass-through', () async {
      final path = await _tempPdf(bytes: 128);
      delegate.openResult = const Success<int>(2);

      final result = await service.open(path.path);

      expect(result, delegate.openResult);
      expect(delegate.calls, ['open:${path.path}']);
    });

    test('renderPage is a pure pass-through', () async {
      delegate.renderResult = const Success<PdfPageImage>(_anyImage);

      final result = await service.renderPage(0);

      expect(result, delegate.renderResult);
      expect(delegate.calls, ['renderPage:0:1.0']);
    });
  });

  group('bucketForBytes', () {
    test('maps sizes onto coarse buckets', () {
      const mb = 1024 * 1024;
      expect(TracedPdfRenderService.bucketForBytes(0), '<1MB');
      expect(TracedPdfRenderService.bucketForBytes(mb - 1), '<1MB');
      expect(TracedPdfRenderService.bucketForBytes(mb), '1-5MB');
      expect(TracedPdfRenderService.bucketForBytes(5 * mb), '5-20MB');
      expect(TracedPdfRenderService.bucketForBytes(20 * mb), '20-50MB');
      expect(TracedPdfRenderService.bucketForBytes(50 * mb), '>=50MB');
    });
  });
}

const PdfPageImage _anyImage = PdfPageImage(
  pageIndex: 0,
  width: 1,
  height: 1,
  bytes: <int>[0, 0, 0, 0],
);

Future<File> _tempPdf({required int bytes}) async {
  final dir = await Directory.systemTemp.createTemp('traced_pdf_test');
  addTearDown(() => dir.delete(recursive: true));
  final file = File('${dir.path}/base.pdf');
  await file.writeAsBytes(List<int>.filled(bytes, 0));
  return file;
}

/// Records every call and returns canned results.
class _FakePdfRenderService implements PdfRenderService {
  final List<String> calls = <String>[];
  Result<int> openResult = const Success<int>(1);
  Result<PdfPageImage> renderResult = const Success<PdfPageImage>(_anyImage);
  Result<PdfPageImage> thumbnailResult = const Success<PdfPageImage>(_anyImage);
  Result<String> checksumResult = const Success<String>('checksum');

  @override
  Future<Result<int>> open(String path) async {
    calls.add('open:$path');
    return openResult;
  }

  @override
  Future<Result<PdfPageImage>> renderPage(
    int pageIndex, {
    double scale = 1,
  }) async {
    calls.add('renderPage:$pageIndex:$scale');
    return renderResult;
  }

  @override
  Future<Result<PdfPageImage>> renderThumbnail(
    int pageIndex, {
    int maxWidth = 96,
  }) async {
    calls.add('renderThumbnail:$pageIndex:$maxWidth');
    return thumbnailResult;
  }

  @override
  Future<Result<String>> checksum(String path) async {
    calls.add('checksum:$path');
    return checksumResult;
  }
}

/// A [PerfTracer] that records started trace names and the traces it hands out.
class _RecordingPerfTracer implements PerfTracer {
  final List<String> started = <String>[];
  final List<_FakePerfTrace> traces = <_FakePerfTrace>[];

  @override
  PerfTrace? start(String name) {
    started.add(name);
    final trace = _FakePerfTrace();
    traces.add(trace);
    return trace;
  }
}

class _FakePerfTrace implements PerfTrace {
  final Map<String, String> attributes = <String, String>{};
  bool stopped = false;
  final Completer<void> _stopped = Completer<void>();

  /// Completes when [stop] is called — lets tests await the fire-and-forget
  /// stop deterministically.
  Future<void> get onStopped => _stopped.future;

  @override
  void putAttribute(String name, String value) => attributes[name] = value;

  @override
  void stop() {
    stopped = true;
    if (!_stopped.isCompleted) _stopped.complete();
  }
}
