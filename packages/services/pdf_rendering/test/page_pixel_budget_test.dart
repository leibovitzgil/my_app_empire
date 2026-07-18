import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

void main() {
  group('fittedRenderScale', () {
    test('leaves a scale that already fits the budget untouched', () {
      // A US-Letter page (612×792 pt) at 3× is ~4.4 MP — well under 16 MP.
      final scale = fittedRenderScale(
        requestedScale: 3,
        pointWidth: 612,
        pointHeight: 792,
      );
      expect(scale, 3);
    });

    test('clamps a scale that would exceed the budget', () {
      final scale = fittedRenderScale(
        requestedScale: 20,
        pointWidth: 612,
        pointHeight: 792,
      );
      // The clamped scale must fill — but never exceed — the 16 MP budget.
      final pixels = 612 * scale * (792 * scale);
      expect(scale, lessThan(20));
      expect(pixels, lessThanOrEqualTo(maxPageImagePixels + 1));
      expect(pixels, greaterThan(maxPageImagePixels - 1));
    });

    test('respects a custom pixel budget', () {
      final scale = fittedRenderScale(
        requestedScale: 10,
        pointWidth: 100,
        pointHeight: 100,
        maxPixels: 1000000,
      );
      // sqrt(1e6) = 1000 px per side => scale 10 over a 100 pt side.
      expect(scale, closeTo(10, 0.001));
    });

    test('passes degenerate inputs through unchanged', () {
      expect(
        fittedRenderScale(requestedScale: 2, pointWidth: 0, pointHeight: 100),
        2,
      );
      expect(
        fittedRenderScale(requestedScale: 0, pointWidth: 100, pointHeight: 100),
        0,
      );
    });
  });
}
