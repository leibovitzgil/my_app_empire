import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:core_utils/core_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:pdf_rendering/src/data/pdf_render_exception.dart';
import 'package:pdf_rendering/src/domain/pdf_page_image.dart';
import 'package:pdf_rendering/src/domain/pdf_render_service.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

/// A [PdfRenderService] backed by `package:pdfrx` (PDFium). Holds at most one
/// open document at a time — [open]ing a new path disposes the previous one.
///
/// Chosen over `pdfx` specifically because PDFium opens
/// **permission-encrypted** PDFs — those carrying an empty user password set
/// only to restrict printing/copying, which are extremely common in published
/// sheet music. `pdfx`'s iOS/macOS backend (`CGPDFDocument`) refuses any
/// encrypted document outright, surfacing every such score as "Invalid PDF
/// format"; [pdfrx.PdfDocument.openFile] retries with an empty password by
/// default and opens them transparently.
class PdfrxRenderService implements PdfRenderService {
  pdfrx.PdfDocument? _document;

  @override
  Future<Result<int>> open(String path) => Result.guard<int>(() async {
    // Idempotent (guarded internally); required before any engine API and
    // safe to await on every open. Kept inside the service so migrating to
    // pdfrx needs no app-level bootstrap change.
    await pdfrx.pdfrxFlutterInitialize();
    final previous = _document;
    _document = null;
    if (previous != null) {
      try {
        await previous.dispose();
      } on Object catch (_) {
        // A failure disposing the previous document shouldn't block opening
        // the new one.
      }
    }
    try {
      final document = await pdfrx.PdfDocument.openFile(path);
      _document = document;
      return document.pages.length;
    } on Object catch (error) {
      throw PdfRenderException('Failed to open PDF at $path: $error');
    }
  });

  @override
  Future<Result<PdfPageImage>> renderPage(int pageIndex, {double scale = 1}) =>
      Result.guard<PdfPageImage>(
        () => _renderAt(pageIndex, (page) => scale),
      );

  @override
  Future<Result<PdfPageImage>> renderThumbnail(
    int pageIndex, {
    int maxWidth = 96,
  }) => Result.guard<PdfPageImage>(
    // A thumbnail is just a low-scale render: fit the page's point width
    // into [maxWidth] pixels (never upscale a page narrower than that).
    () => _renderAt(
      pageIndex,
      (page) => math.min(1, maxWidth / page.width),
    ),
  );

  /// Renders [pageIndex] at the scale [scaleFor] computes from the page
  /// (so callers can derive it from the page's own dimensions).
  Future<PdfPageImage> _renderAt(
    int pageIndex,
    double Function(pdfrx.PdfPage page) scaleFor,
  ) async {
    final document = _document;
    if (document == null) {
      throw const PdfRenderException(
        'renderPage was called before a document was open()ed',
      );
    }
    final pages = document.pages;
    if (pageIndex < 0 || pageIndex >= pages.length) {
      throw PdfRenderException(
        'Page $pageIndex is out of range (0..${pages.length - 1})',
      );
    }
    try {
      final page = pages[pageIndex];
      final scale = scaleFor(page);
      // Omit width/height so the full page is rendered; fullWidth/
      // fullHeight set the target resolution (page points × scale).
      final rendered = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
      );
      if (rendered == null) {
        throw const PdfRenderException(
          'pdfrx returned no image for the requested page',
        );
      }
      try {
        return PdfPageImage(
          pageIndex: pageIndex,
          width: rendered.width,
          height: rendered.height,
          bytes: _bgraToRgba(rendered.pixels),
        );
      } finally {
        rendered.dispose();
      }
    } on PdfRenderException {
      rethrow;
    } on Object catch (error) {
      throw PdfRenderException('Failed to render page $pageIndex: $error');
    }
  }

  /// pdfrx emits pixels as BGRA8888, but our contract (and
  /// `ScorePageCanvas`'s `decodeImageFromPixels(..., PixelFormat.rgba8888)`)
  /// is RGBA8888 — swap the B and R channels into a fresh buffer.
  Uint8List _bgraToRgba(Uint8List bgra) {
    final rgba = Uint8List(bgra.length);
    for (var i = 0; i + 3 < bgra.length; i += 4) {
      rgba[i] = bgra[i + 2];
      rgba[i + 1] = bgra[i + 1];
      rgba[i + 2] = bgra[i];
      rgba[i + 3] = bgra[i + 3];
    }
    return rgba;
  }

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
