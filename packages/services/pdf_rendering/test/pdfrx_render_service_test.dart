import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

void main() {
  group('PdfrxRenderService', () {
    late Directory tempDir;
    late PdfrxRenderService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pdf_render_test');
      service = PdfrxRenderService();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('checksum computes a stable sha256 of the file bytes', () async {
      final file = File('${tempDir.path}/a.pdf')..writeAsBytesSync([1, 2, 3]);

      final result = await service.checksum(file.path);

      expect(result, isA<Success<String>>());
      final expected = sha256.convert([1, 2, 3]).toString();
      expect((result as Success<String>).value, expected);
    });

    test('checksum is deterministic for identical content', () async {
      final fileA = File('${tempDir.path}/a.pdf')..writeAsBytesSync([9, 9, 9]);
      final fileB = File('${tempDir.path}/b.pdf')..writeAsBytesSync([9, 9, 9]);

      final resultA = await service.checksum(fileA.path);
      final resultB = await service.checksum(fileB.path);

      expect(
        (resultA as Success<String>).value,
        (resultB as Success<String>).value,
      );
    });

    test('checksum differs for different content', () async {
      final fileA = File('${tempDir.path}/a.pdf')..writeAsBytesSync([1, 2, 3]);
      final fileB = File('${tempDir.path}/b.pdf')..writeAsBytesSync([4, 5, 6]);

      final resultA = await service.checksum(fileA.path);
      final resultB = await service.checksum(fileB.path);

      expect(
        (resultA as Success<String>).value,
        isNot((resultB as Success<String>).value),
      );
    });

    test('checksum fails for a missing file', () async {
      final result = await service.checksum('${tempDir.path}/missing.pdf');

      expect(result, isA<ResultFailure<String>>());
      expect(
        (result as ResultFailure<String>).error,
        isA<PdfRenderException>(),
      );
    });

    test('renderPage fails before a document is open()ed', () async {
      final result = await service.renderPage(0);

      expect(result, isA<ResultFailure<PdfPageImage>>());
      expect(
        (result as ResultFailure<PdfPageImage>).error,
        isA<PdfRenderException>(),
      );
    });

    test('renderThumbnail fails before a document is open()ed', () async {
      final result = await service.renderThumbnail(0);

      expect(result, isA<ResultFailure<PdfPageImage>>());
      expect(
        (result as ResultFailure<PdfPageImage>).error,
        isA<PdfRenderException>(),
      );
    });

    // `open` and `renderPage`'s actual pdfrx interaction both need the PDFium
    // engine initialized via a real platform (Android/iOS/macOS/Windows/Web)
    // and aren't exercised in a plain `flutter test` VM run here, so `open`'s
    // success path and `renderPage`'s rasterization need on-device or
    // integration-test verification instead. `renderPage`'s pre-`open()`
    // guard above is exercised without touching pdfrx at all, so it's safe to
    // unit test.
  });
}
