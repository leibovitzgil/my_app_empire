import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppCard', () {
    testWidgets('fires onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              onTap: () => tapped = true,
              child: const Text('Content'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('changes background color when selected', (tester) async {
      final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

      Future<void> pump({required bool selected}) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme, useMaterial3: true),
          home: Scaffold(
            body: AppCard(selected: selected, child: const Text('Content')),
          ),
        ),
      );

      await pump(selected: false);
      final defaultCard = tester.widget<Card>(find.byType(Card));
      expect(defaultCard.color, isNot(scheme.primaryContainer));

      await pump(selected: true);
      final selectedCard = tester.widget<Card>(find.byType(Card));
      expect(selectedCard.color, scheme.primaryContainer);
    });

    testWidgets('blocks tap and reduces opacity when disabled', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              enabled: false,
              onTap: () => tapped = true,
              child: const Text('Content'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppCard), warnIfMissed: false);
      await tester.pump();

      expect(tapped, isFalse);
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.5);
      final ignorePointer = tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignorePointer.ignoring, isTrue);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('has no InkWell when onTap is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppCard(child: Text('Content'))),
        ),
      );

      expect(find.byType(InkWell), findsNothing);
    });
  });
}
