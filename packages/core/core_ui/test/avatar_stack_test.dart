import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvatarStack', () {
    testWidgets('renders nothing for an empty roster', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AvatarStack(people: [])),
        ),
      );

      expect(find.byType(InitialsAvatar), findsNothing);
    });

    testWidgets('renders one avatar per person under maxVisible', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarStack(
              people: [
                (initials: 'GL', color: Colors.indigo),
                (initials: 'AM', color: Colors.teal),
              ],
            ),
          ),
        ),
      );

      expect(find.text('GL'), findsOneWidget);
      expect(find.text('AM'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('folds anything past maxVisible into a "+N" badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarStack(
              people: [
                (initials: 'GL', color: Colors.indigo),
                (initials: 'AM', color: Colors.teal),
                (initials: 'JD', color: Colors.orange),
                (initials: 'RK', color: Colors.pink),
              ],
            ),
          ),
        ),
      );

      expect(find.text('GL'), findsOneWidget);
      expect(find.text('AM'), findsOneWidget);
      expect(find.text('JD'), findsOneWidget);
      expect(find.text('RK'), findsNothing);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('exposes a default "N collaborators" semantic label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarStack(
              people: [
                (initials: 'GL', color: Colors.indigo),
                (initials: 'AM', color: Colors.teal),
              ],
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('2 collaborators'), findsOneWidget);
      handle.dispose();
    });
  });
}
