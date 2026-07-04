import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LabeledToggleChip', () {
    testWidgets('fires onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LabeledToggleChip(
              label: 'Teacher',
              icon: Icons.school_outlined,
              selected: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(LabeledToggleChip));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('changes background colour when selected', (tester) async {
      final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

      Future<void> pump({required bool selected}) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme, useMaterial3: true),
          home: Scaffold(
            body: LabeledToggleChip(
              label: 'Teacher',
              icon: Icons.school_outlined,
              selected: selected,
              onTap: () {},
            ),
          ),
        ),
      );

      final chipMaterial = find.descendant(
        of: find.byType(LabeledToggleChip),
        matching: find.byType(Material),
      );

      await pump(selected: false);
      final unselected = tester.widget<Material>(chipMaterial);
      expect(unselected.color, isNot(scheme.primaryContainer));

      await pump(selected: true);
      final selectedMaterial = tester.widget<Material>(chipMaterial);
      expect(selectedMaterial.color, scheme.primaryContainer);
    });

    testWidgets('shows an owned pencil glyph only when owned', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LabeledToggleChip(
              label: 'Teacher',
              icon: Icons.school_outlined,
              selected: false,
              owned: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('hides the owned pencil glyph by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LabeledToggleChip(
              label: 'Teacher',
              icon: Icons.school_outlined,
              selected: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsNothing);
    });
  });
}
