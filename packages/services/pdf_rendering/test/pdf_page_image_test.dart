import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

void main() {
  test('PdfPageImage supports value equality', () {
    const image = PdfPageImage(
      pageIndex: 0,
      width: 100,
      height: 200,
      bytes: [1, 2, 3],
    );

    expect(
      image,
      const PdfPageImage(
        pageIndex: 0,
        width: 100,
        height: 200,
        bytes: [
          1,
          2,
          3,
        ],
      ),
    );
  });
}
