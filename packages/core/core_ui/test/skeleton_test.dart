import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SkeletonBox', () {
    testWidgets('renders a static box when shimmer is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SkeletonBox(width: 100, shimmer: false)),
        ),
      );

      expect(find.byType(SkeletonBox), findsOneWidget);
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('renders without error when shimmer is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SkeletonBox(width: 100)),
        ),
      );
      // A single non-zero pump flushes flutter_animate's initial delayed
      // start future; the repeat itself is driven by ticker frames that
      // only advance on further explicit pumps, so this never hangs.
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.byType(SkeletonBox), findsOneWidget);
    });

    testWidgets('is excluded from semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SkeletonBox(width: 100, shimmer: false)),
        ),
      );

      final semantics = tester.getSemantics(find.byType(SkeletonBox));
      expect(semantics.label, isEmpty);
      handle.dispose();
    });
  });

  group('SkeletonList', () {
    testWidgets('renders itemCount SkeletonBox rows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonList(itemCount: 5, shimmer: false),
          ),
        ),
      );

      expect(find.byType(SkeletonBox), findsNWidgets(5));
    });

    testWidgets('defaults to 3 items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SkeletonList(shimmer: false)),
        ),
      );

      expect(find.byType(SkeletonBox), findsNWidgets(3));
    });

    testWidgets('exposes a single group semantics label', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SkeletonList(shimmer: false)),
        ),
      );

      expect(find.bySemanticsLabel('Loading content'), findsOneWidget);
      handle.dispose();
    });
  });
}
