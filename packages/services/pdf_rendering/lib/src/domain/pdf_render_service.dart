import 'package:core_utils/core_utils.dart';
import 'package:pdf_rendering/src/domain/pdf_page_image.dart';

/// Contract for opening a PDF, paging through it, rendering pages to
/// bitmaps, and checksumming its contents.
abstract class PdfRenderService {
  /// Opens the PDF at [path], returning its page count.
  Future<Result<int>> open(String path);

  /// Renders the page at [pageIndex] (of a previously [open]ed document),
  /// at the given [scale] factor.
  Future<Result<PdfPageImage>> renderPage(int pageIndex, {double scale = 1});

  /// Renders a small thumbnail of the page at [pageIndex] (of a previously
  /// [open]ed document), at most [maxWidth] pixels wide (height follows the
  /// page's aspect ratio). A cheap low-scale render for page rails and
  /// previews — callers cache the decoded result keyed by
  /// ([checksum], page index).
  Future<Result<PdfPageImage>> renderThumbnail(
    int pageIndex, {
    int maxWidth = 96,
  });

  /// Computes a content checksum of the PDF at [path], used to detect
  /// drift between copies and to key cached renders.
  Future<Result<String>> checksum(String path);
}
