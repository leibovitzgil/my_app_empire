import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:pdf_rendering/src/data/pdf_render_exception.dart';
import 'package:pdf_rendering/src/domain/pdf_page_image.dart';
import 'package:pdf_rendering/src/domain/pdf_render_service.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

/// A [PdfRenderService] backed by `package:pdfx`. Holds at most one open
/// document at a time — [open]ing a new path closes the previous one — to
/// match `pdfx`'s "one page open at a time" native rendering constraint.
class PdfxRenderService implements PdfRenderService {
  pdfx.PdfDocument? _document;

  @override
  Future<Result<int>> open(String path) => Result.guard<int>(() async {
    final previous = _document;
    _document = null;
    if (previous != null) {
      try {
        await previous.close();
      } on Object catch (_) {
        // A failure closing the previous document shouldn't block opening
        // the new one.
      }
    }
    try {
      final document = await pdfx.PdfDocument.openFile(path);
      _document = document;
      return document.pagesCount;
    } on Object catch (error) {
      throw PdfRenderException('Failed to open PDF at $path: $error');
    }
  });

  @override
  Future<Result<PdfPageImage>> renderPage(int pageIndex, {double scale = 1}) =>
      Result.guard<PdfPageImage>(() async {
        final document = _document;
        if (document == null) {
          throw const PdfRenderException(
            'renderPage was called before a document was open()ed',
          );
        }
        pdfx.PdfPage? page;
        try {
          // pdfx pages are 1-based; our contract's pageIndex is 0-based.
          page = await document.getPage(pageIndex + 1);
          final rendered = await page.render(
            width: page.width * scale,
            height: page.height * scale,
          );
          if (rendered == null) {
            throw const PdfRenderException(
              'pdfx returned no image for the requested page',
            );
          }
          return PdfPageImage(
            pageIndex: pageIndex,
            width: rendered.width ?? 0,
            height: rendered.height ?? 0,
            bytes: rendered.bytes,
          );
        } on PdfRenderException {
          rethrow;
        } on Object catch (error) {
          throw PdfRenderException(
            'Failed to render page $pageIndex: $error',
          );
        } finally {
          await page?.close();
        }
      });

  @override
  Future<Result<String>> checksum(String path) =>
      Result.guard<String>(() async {
        try {
          final bytes = await File(path).readAsBytes();
          return sha256.convert(bytes).toString();
        } on Object catch (error) {
          throw PdfRenderException('Failed to checksum $path: $error');
        }
      });
}
