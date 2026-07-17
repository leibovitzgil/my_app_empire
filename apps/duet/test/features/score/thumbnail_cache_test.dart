import 'package:core_utils/core_utils.dart';
import 'package:duet/features/score/score.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

/// Counts [renderThumbnail] calls and can be flipped into failure mode, so
/// tests can assert cache hits/misses and the no-failure-caching rule.
class _CountingRenderService implements PdfRenderService {
  int renderThumbnailCalls = 0;
  bool fail = false;

  @override
  Future<Result<int>> open(String path) async => const Success(1);

  @override
  Future<Result<PdfPageImage>> renderPage(int pageIndex, {double scale = 1}) =>
      throw UnimplementedError();

  @override
  Future<Result<PdfPageImage>> renderThumbnail(
    int pageIndex, {
    int maxWidth = 96,
  }) async {
    renderThumbnailCalls++;
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
  Future<Result<String>> checksum(String path) async => const Success('sum');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThumbnailCache', () {
    late _CountingRenderService service;
    late ThumbnailCache cache;

    setUp(() {
      service = _CountingRenderService();
      cache = ThumbnailCache(renderService: service, capacity: 3);
    });

    tearDown(() => cache.dispose());

    test('decodes a rendered thumbnail at its pixel dimensions', () async {
      final image = await cache.thumbnail(checksum: 'a', pageIndex: 0);

      expect(image, isNotNull);
      expect(image!.width, 4);
      expect(image.height, 6);
      image.dispose();
    });

    test(
      'serves repeat requests from the cache (one render per key)',
      () async {
        final first = await cache.thumbnail(checksum: 'a', pageIndex: 0);
        final second = await cache.thumbnail(checksum: 'a', pageIndex: 0);

        expect(service.renderThumbnailCalls, 1);
        first?.dispose();
        second?.dispose();
      },
    );

    test('keys entries by checksum AND page index', () async {
      (await cache.thumbnail(checksum: 'a', pageIndex: 0))?.dispose();
      (await cache.thumbnail(checksum: 'b', pageIndex: 0))?.dispose();
      (await cache.thumbnail(checksum: 'a', pageIndex: 0))?.dispose();

      expect(service.renderThumbnailCalls, 2);
    });

    test('concurrent requests for one page share a single render', () async {
      final images = await Future.wait([
        cache.thumbnail(checksum: 'a', pageIndex: 0),
        cache.thumbnail(checksum: 'a', pageIndex: 0),
      ]);

      expect(service.renderThumbnailCalls, 1);
      expect(images, everyElement(isNotNull));
      for (final image in images) {
        image?.dispose();
      }
    });

    test('evicts least-recently-used entries beyond capacity', () async {
      for (var page = 0; page < 4; page++) {
        (await cache.thumbnail(checksum: 'a', pageIndex: page))?.dispose();
      }
      expect(cache.length, 3);

      // Page 0 was evicted (LRU) — re-requesting it renders again...
      (await cache.thumbnail(checksum: 'a', pageIndex: 0))?.dispose();
      expect(service.renderThumbnailCalls, 5);

      // ...while page 3 is still cached.
      (await cache.thumbnail(checksum: 'a', pageIndex: 3))?.dispose();
      expect(service.renderThumbnailCalls, 5);
    });

    test('a cache hit refreshes recency', () async {
      for (var page = 0; page < 3; page++) {
        (await cache.thumbnail(checksum: 'a', pageIndex: page))?.dispose();
      }
      // Touch page 0 so page 1 becomes the LRU, then overflow.
      (await cache.thumbnail(checksum: 'a', pageIndex: 0))?.dispose();
      (await cache.thumbnail(checksum: 'a', pageIndex: 3))?.dispose();

      // Page 0 must still be a hit (4 misses so far: pages 0,1,2,3).
      (await cache.thumbnail(checksum: 'a', pageIndex: 0))?.dispose();
      expect(service.renderThumbnailCalls, 4);
    });

    test('disposing a returned clone leaves the cached image usable', () async {
      final first = await cache.thumbnail(checksum: 'a', pageIndex: 0);
      first!.dispose();

      final second = await cache.thumbnail(checksum: 'a', pageIndex: 0);
      expect(second, isNotNull);
      expect(second!.width, 4);
      second.dispose();
      expect(service.renderThumbnailCalls, 1);
    });

    test('a failed render resolves null and is never cached', () async {
      service.fail = true;
      final image = await cache.thumbnail(checksum: 'a', pageIndex: 0);
      expect(image, isNull);
      expect(cache.length, 0);

      // The next request retries — and can succeed.
      service.fail = false;
      final retried = await cache.thumbnail(checksum: 'a', pageIndex: 0);
      expect(retried, isNotNull);
      expect(service.renderThumbnailCalls, 2);
      retried?.dispose();
    });

    test('after dispose, requests resolve null without rendering', () async {
      cache.dispose();

      final image = await cache.thumbnail(checksum: 'a', pageIndex: 0);
      expect(image, isNull);
      expect(service.renderThumbnailCalls, 0);
    });
  });
}
