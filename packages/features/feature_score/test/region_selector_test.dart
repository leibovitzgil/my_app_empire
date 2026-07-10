import 'package:feature_score/feature_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pieces/pieces.dart';

Future<void> _pump(
  WidgetTester tester, {
  ValueChanged<Region>? onRegionPreview,
  ValueChanged<Region>? onRegionCompleted,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 300,
          child: RegionSelector(
            pageIndex: 0,
            onRegionPreview: onRegionPreview ?? (_) {},
            onRegionCompleted: onRegionCompleted ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('RegionSelector', () {
    testWidgets('a drag past the minimum size calls onRegionCompleted once', (
      tester,
    ) async {
      final completed = <Region>[];
      await _pump(tester, onRegionCompleted: completed.add);

      final gesture = await tester.startGesture(const Offset(20, 20));
      await gesture.moveTo(const Offset(120, 160));
      await gesture.up();
      await tester.pump();

      expect(completed, hasLength(1));
      final region = completed.single;
      expect(region.pageIndex, 0);
      expect(region.left, closeTo(20 / 300, 0.01));
      expect(region.top, closeTo(20 / 300, 0.01));
      expect(region.width, closeTo(100 / 300, 0.01));
      expect(region.height, closeTo(140 / 300, 0.01));
    });

    testWidgets('a drag under the minimum size never completes', (
      tester,
    ) async {
      final completed = <Region>[];
      await _pump(tester, onRegionCompleted: completed.add);

      final gesture = await tester.startGesture(const Offset(20, 20));
      await gesture.moveTo(const Offset(25, 25));
      await gesture.up();
      await tester.pump();

      expect(completed, isEmpty);
    });

    testWidgets('dragging reports live preview updates', (tester) async {
      final previews = <Region>[];
      await _pump(tester, onRegionPreview: previews.add);

      final gesture = await tester.startGesture(const Offset(20, 20));
      await gesture.moveTo(const Offset(80, 80));
      await gesture.moveTo(const Offset(120, 160));
      await gesture.up();
      await tester.pump();

      expect(previews.length, greaterThanOrEqualTo(2));
    });
  });
}
