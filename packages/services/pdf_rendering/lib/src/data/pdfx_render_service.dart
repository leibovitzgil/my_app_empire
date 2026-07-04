import 'package:core_utils/core_utils.dart';
import 'package:pdf_rendering/src/domain/pdf_page_image.dart';
import 'package:pdf_rendering/src/domain/pdf_render_service.dart';

/// A [PdfRenderService] backed by `package:pdfx`. Real rendering lands in a
/// later phase; this keeps the package compiling end-to-end against the
/// contract in the meantime.
class PdfxRenderService implements PdfRenderService {
  @override
  Future<Result<int>> open(String path) => throw UnimplementedError();

  @override
  Future<Result<PdfPageImage>> renderPage(int pageIndex, {double scale = 1}) =>
      throw UnimplementedError();

  @override
  Future<Result<String>> checksum(String path) => throw UnimplementedError();
}
