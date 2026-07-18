import 'package:core_utils/core_utils.dart';
import 'package:duet/features/score/score.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

/// Counts [renderPage] calls (with the scale each was asked for) and can be
/// flipped into failure mode, so tests can assert cache hits/misses, the
/// sharper-on-zoom re-render, and the no-failure-caching rule.
class _CountingRenderService implements PdfRenderService {
  final List<double> renderScales = <double>[];
  bool fail = false;

  int get renderPageCalls => renderScales.length;

  @override
  Future<Result<int>> open(String path) async => const Success(1);

  @override
  Future<Result<PdfPageImage>> renderPage(
    int pageIndex, {
    double scale = 1,
  }) async {
    renderScales.add(scale);
    if (fail) {
      return ResultFailure<PdfPageImage>(StateError('render failed'));
    }
    return Success(
      PdfPageImage(
        pageIndex: pageIndex,
        width: 4,
        height: 6,
        bytes: List<int>.filled(4 * 6 * 4, 255),
      ),
    );
  }

  @override
  Future<Result<PdfPageImage>> renderThumbnail(
    int pageIndex, {
    int maxWidth = 96,
  }) => throw UnimplementedError();

  @override
  Future<Result<String>> checksum(String path) async => const Success('sum');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PageImageCache', () {
    late _CountingRenderService service;
    late PageImageCache cache;

    setUp(() {
      service = _CountingRenderService();
      cache = PageImageCache(renderService: service);
    });

    tearDown(() => cache.dispose());

    test('decodes a rendered page at its pixel dimensions', () async {
      final image = await cache.page(checksum: 'a', pageIndex: 0, scale: 2);

      expect(image, isNotNull);
      expect(image!.width, 4);
      expect(image.height, 6);
      image.dispose();
    });

    test(
      'serves repeat requests from the cache (one render per key)',
      () async {
        final first = await cache.page(checksum: 'a', pageIndex: 0, scale: 2);
        final second = await cache.page(checksum: 'a', pageIndex: 0, scale: 2);

        expect(service.renderPageCalls, 1);
        first?.dispose();
        second?.dispose();
      },
    );

    test('keys entries by checksum AND page index', () async {
      (await cache.page(checksum: 'a', pageIndex: 0, scale: 2))?.dispose();
      (await cache.page(checksum: 'b', pageIndex: 0, scale: 2))?.dispose();
      (await cache.page(checksum: 'a', pageIndex: 0, scale: 2))?.dispose();

      expect(service.renderPageCalls, 2);
    });

    test('a request no sharper than the cached copy is a hit', () async {
      (await cache.page(checksum: 'a', pageIndex: 0, scale: 3))?.dispose();
      // A lower (or equal) scale is satisfied by the sharper cached image.
      (await cache.page(checksum: 'a', pageIndex: 0, scale: 2))?.dispose();

      expect(service.renderPageCalls, 1);
    });

    test(
      'a sharper request re-renders and replaces the coarser image',
      () async {
        (await cache.page(checksum: 'a', pageIndex: 0, scale: 2))?.dispose();
        (await cache.page(checksum: 'a', pageIndex: 0, scale: 4))?.dispose();

        expect(service.renderScales, [2, 4]);
        expect(cache.length, 1);

        // The sharper image now satisfies scale 2 without rendering again.
        (await cache.page(checksum: 'a', pageIndex: 0, scale: 2))?.dispose();
        expect(service.renderPageCalls, 2);
      },
    );

    test('concurrent requests for one page share a single render', () async {
      final images = await Future.wait([
        cache.page(checksum: 'a', pageIndex: 0, scale: 2),
        cache.page(checksum: 'a', pageIndex: 0, scale: 2),
      ]);

      expect(service.renderPageCalls, 1);
      expect(images, everyElement(isNotNull));
      for (final image in images) {
        image?.dispose();
      }
    });

    test('evicts least-recently-used entries beyond capacity', () async {
      for (var page = 0; page < 4; page++) {
        (await cache.page(checksum: 'a', pageIndex: page, scale: 2))?.dispose();
      }
      expect(cache.length, 3);

      // Page 0 was evicted (LRU) — re-requesting it renders again...
      (await cache.page(checksum: 'a', pageIndex: 0, scale: 2))?.dispose();
      expect(service.renderPageCalls, 5);

      // ...while page 3 is still cached.
      (await cache.page(checksum: 'a', pageIndex: 3, scale: 2))?.dispose();
      expect(service.renderPageCalls, 5);
    });

    test('a cache hit refreshes recency', () async {
      for (var page = 0; page < 3; page++) {
        (await cache.page(checksum: 'a', pageIndex: page, scale: 2))?.dispose();
      }
      // Touch page 0 so page 1 becomes the LRU, then overflow.
      (await cache.page(checksum: 'a', pageIndex: 0, scale: 2))?.dispose();
      (await cache.page(checksum: 'a', pageIndex: 3, scale: 2))?.dispose();

      // Page 0 must still be a hit (4 misses so far: pages 0,1,2,3).
      (await cache.page(checksum: 'a', pageIndex: 0, scale: 2))?.dispose();
      expect(service.renderPageCalls, 4);
    });

    test('disposing a returned clone leaves the cached image usable', () async {
      final first = await cache.page(checksum: 'a', pageIndex: 0, scale: 2);
      first!.dispose();

      final second = await cache.page(checksum: 'a', pageIndex: 0, scale: 2);
      expect(second, isNotNull);
      expect(second!.width, 4);
      second.dispose();
      expect(service.renderPageCalls, 1);
    });

    test('a failed render resolves null and is never cached', () async {
      service.fail = true;
      final image = await cache.page(checksum: 'a', pageIndex: 0, scale: 2);
      expect(image, isNull);
      expect(cache.length, 0);

      // The next request retries — and can succeed.
      service.fail = false;
      final retried = await cache.page(checksum: 'a', pageIndex: 0, scale: 2);
      expect(retried, isNotNull);
      expect(service.renderPageCalls, 2);
      retried?.dispose();
    });

    test('after dispose, requests resolve null without rendering', () async {
      cache.dispose();

      final image = await cache.page(checksum: 'a', pageIndex: 0, scale: 2);
      expect(image, isNull);
      expect(service.renderPageCalls, 0);
    });
  });
}
