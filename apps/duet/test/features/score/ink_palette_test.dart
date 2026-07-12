import 'package:duet/features/score/score.dart';
import 'package:duet/features/score/src/ink_color_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ink palette', () {
    test('kInkPaletteSize matches the actual palette length', () {
      // `ScoreBloc` cycles participant colours modulo `kInkPaletteSize`
      // without importing the UI palette; the two must agree.
      expect(kInkPalette, hasLength(kInkPaletteSize));
    });

    test('inkColorIdFor cycles within the palette', () {
      expect(inkColorIdFor(0), 'p0');
      expect(inkColorIdFor(kInkPaletteSize - 1), 'p${kInkPaletteSize - 1}');
      // Wraps rather than producing an out-of-range id.
      expect(inkColorIdFor(kInkPaletteSize), 'p0');
      expect(inkColorIdFor(kInkPaletteSize + 1), 'p1');
    });

    test('every cycled colour id resolves to a real palette colour', () {
      for (var i = 0; i < kInkPaletteSize * 2; i++) {
        expect(kInkPalette, contains(inkColorForId(inkColorIdFor(i))));
      }
    });
  });
}
