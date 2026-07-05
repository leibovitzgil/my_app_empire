import 'package:feature_score/src/ui/widgets/fractional_region_align.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pieces/pieces.dart';

void main() {
  group('FractionalRegionAlign', () {
    testWidgets('centers its child at the region centroid', (tester) async {
      const region = Region(
        pageIndex: 0,
        left: 0.2,
        top: 0.4,
        width: 0.2,
        height: 0.2,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: FractionalRegionAlign(
                region: region,
                child: SizedBox(key: Key('child'), width: 10, height: 10),
              ),
            ),
          ),
        ),
      );

      final align = tester.widget<Align>(find.byType(Align));
      // centroid = (left + width/2, top + height/2) = (0.3, 0.5), mapped to
      // Alignment's [-1, 1] space via `2 * v - 1`.
      final alignment = align.alignment as Alignment;
      expect(alignment.x, closeTo(-0.4, 1e-9));
      expect(alignment.y, closeTo(0.0, 1e-9));
      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('a region at the top-left corner aligns to (-1, -1)', (
      tester,
    ) async {
      const region = Region(
        pageIndex: 0,
        left: 0,
        top: 0,
        width: 0,
        height: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: FractionalRegionAlign(
                region: region,
                child: SizedBox(width: 10, height: 10),
              ),
            ),
          ),
        ),
      );

      final align = tester.widget<Align>(find.byType(Align));
      expect(align.alignment, Alignment.topLeft);
    });

    testWidgets(
      'a region spanning the full page aligns its centroid to the center',
      (tester) async {
        const region = Region(
          pageIndex: 0,
          left: 0,
          top: 0,
          width: 1,
          height: 1,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(
                child: FractionalRegionAlign(
                  region: region,
                  child: SizedBox(width: 10, height: 10),
                ),
              ),
            ),
          ),
        );

        final align = tester.widget<Align>(find.byType(Align));
        expect(align.alignment, Alignment.center);
      },
    );
  });
}
