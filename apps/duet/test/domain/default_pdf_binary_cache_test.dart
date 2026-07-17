import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [PieceBinaryStore] whose `downloadBasePdf` writes [content] to the
/// destination and counts calls — the network stand-in.
class _FakeBinaryStore implements PieceBinaryStore {
  String content = 'pdf-bytes';
  bool fail = false;
  int downloads = 0;

  @override
  Future<Result<void>> downloadBasePdf({
    required String pieceId,
    required String destPath,
  }) => Result.guard<void>(() async {
    downloads++;
    if (fail) throw const SocketException('offline');
    File(destPath).writeAsStringSync(content);
  });

  @override
  Stream<UploadProgress> uploadBasePdf({
    required String pieceId,
    required String localPath,
    required String checksum,
  }) => throw UnimplementedError();
}

/// Checksums a file as `sum:<contents>`, so a test controls whether a
/// downloaded file "verifies" by choosing the piece's expected checksum.
class _ContentPdfRenderService implements PdfRenderService {
  @override
  Future<Result<String>> checksum(String path) async =>
      Success('sum:${File(path).readAsStringSync()}');

  @override
  Future<Result<int>> open(String path) => throw UnimplementedError();

  @override
  Future<Result<PdfPageImage>> renderPage(int pageIndex, {double scale = 1}) =>
      throw UnimplementedError();

  @override
  Future<Result<PdfPageImage>> renderThumbnail(
    int pageIndex, {
    int maxWidth = 96,
  }) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DefaultPdfBinaryCache', () {
    late Directory tempDir;
    late LocalStorageService storage;
    late _FakeBinaryStore store;

    Future<Directory> documentsDirectory() async => tempDir;

    Piece pieceWith({required String checksum, String basePdfPath = ''}) =>
        Piece(
          id: 'p1',
          title: 'Nocturne',
          basePdfChecksum: checksum,
          basePdfPath: basePdfPath,
          ownerId: 'owner-1',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

    DefaultPdfBinaryCache buildCache({int maxCacheBytes = 1 << 30}) =>
        DefaultPdfBinaryCache(
          binaryStore: store,
          pdfRenderService: _ContentPdfRenderService(),
          storage: storage,
          documentsDirectory: documentsDirectory,
          maxCacheBytes: maxCacheBytes,
        );

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pdf_cache');
      SharedPreferences.setMockInitialValues(<String, Object>{});
      storage = LocalStorageService(await SharedPreferences.getInstance());
      store = _FakeBinaryStore();
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    File cacheFileFor(String checksum) =>
        File(p.join(tempDir.path, 'pieces_cache', '$checksum.pdf'));

    test('a cache hit returns the cached path without downloading', () async {
      cacheFileFor('abc').parent.createSync(recursive: true);
      cacheFileFor('abc').writeAsStringSync('cached');

      final path = (await buildCache().pathFor(
        pieceWith(checksum: 'abc'),
      )).orThrow();

      expect(path, cacheFileFor('abc').path);
      expect(store.downloads, 0);
    });

    test(
      'an on-device copy is returned directly (no download, no copy)',
      () async {
        final local = File('${tempDir.path}/staged.pdf')
          ..writeAsStringSync('local');

        final path = (await buildCache().pathFor(
          pieceWith(checksum: 'abc', basePdfPath: local.path),
        )).orThrow();

        expect(path, local.path);
        expect(store.downloads, 0);
        // The cache dir is untouched — no second blob store for local pieces.
        expect(cacheFileFor('abc').existsSync(), isFalse);
      },
    );

    test('a miss downloads, verifies, and caches by checksum', () async {
      store.content = 'the-bytes';

      final path = (await buildCache().pathFor(
        pieceWith(checksum: 'sum:the-bytes'),
      )).orThrow();

      expect(path, cacheFileFor('sum:the-bytes').path);
      expect(File(path).readAsStringSync(), 'the-bytes');
      expect(store.downloads, 1);
    });

    test('a re-open after a download hits the cache (offline-safe)', () async {
      store.content = 'the-bytes';
      final piece = pieceWith(checksum: 'sum:the-bytes');
      final cache = buildCache();

      (await cache.pathFor(piece)).orThrow();
      // Second resolve must not hit the network again.
      store.fail = true;
      final path = (await cache.pathFor(piece)).orThrow();

      expect(path, cacheFileFor('sum:the-bytes').path);
      expect(store.downloads, 1);
    });

    test(
      'a checksum mismatch re-downloads once, then fails and cleans up',
      () async {
        store.content = 'corrupt';
        final result = await buildCache().pathFor(
          pieceWith(checksum: 'sum:expected'),
        );

        expect(result, isA<ResultFailure<String>>());
        expect(store.downloads, 2); // one retry
        expect(cacheFileFor('sum:expected').existsSync(), isFalse);
      },
    );

    test('a download failure surfaces as a Result failure', () async {
      store.fail = true;
      final result = await buildCache().pathFor(pieceWith(checksum: 'abc'));
      expect(result, isA<ResultFailure<String>>());
    });

    test('evicts the least-recently-opened file when over the cap', () async {
      // Each downloaded file is 5 bytes; cap at 8 forces one eviction.
      final cache = buildCache(maxCacheBytes: 8);
      store.content = 'aaaaa';
      (await cache.pathFor(pieceWith(checksum: 'sum:aaaaa'))).orThrow();
      store.content = 'bbbbb';
      (await cache.pathFor(pieceWith(checksum: 'sum:bbbbb'))).orThrow();

      // The first (least-recently-opened) is evicted; the newest remains.
      expect(cacheFileFor('sum:aaaaa').existsSync(), isFalse);
      expect(cacheFileFor('sum:bbbbb').existsSync(), isTrue);
    });
  });
}
