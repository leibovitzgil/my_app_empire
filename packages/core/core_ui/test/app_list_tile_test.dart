import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppListTile', () {
    testWidgets('fires onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppListTile(
              title: const Text('Buy milk'),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppListTile));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('is disabled when enabled is false', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppListTile(
              title: const Text('Buy milk'),
              enabled: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.enabled, isFalse);

      await tester.tap(find.byType(AppListTile), warnIfMissed: false);
      await tester.pump();
      expect(tapped, isFalse);
    });

    testWidgets('renders leading, subtitle and trailing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('Buy milk'),
              subtitle: Text('Added by Gil'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.text('Added by Gil'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('PersonTile', () {
    testWidgets('renders name, subtitle and avatar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PersonTile(
              initials: 'GL',
              color: Colors.indigo,
              name: 'Gil Leibovich',
              subtitle: 'gil@example.com',
            ),
          ),
        ),
      );

      expect(find.text('Gil Leibovich'), findsOneWidget);
      expect(find.text('gil@example.com'), findsOneWidget);
      expect(find.byType(InitialsAvatar), findsOneWidget);
      expect(find.text('GL'), findsOneWidget);
    });

    testWidgets('fires onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonTile(
              initials: 'GL',
              color: Colors.indigo,
              name: 'Gil Leibovich',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PersonTile));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('excludes the avatar from the semantics tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PersonTile(
              initials: 'GL',
              color: Colors.indigo,
              name: 'Gil Leibovich',
              subtitle: 'gil@example.com',
            ),
          ),
        ),
      );

      // The avatar's own semantics (a standalone "GL" label) must not be
      // announced separately — only a single merged node carrying the
      // name/subtitle (surfaced by ListTile) should exist.
      expect(find.bySemanticsLabel(RegExp(r'^GL$')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Gil Leibovich')), findsOneWidget);

      final personTileSemantics = tester.getSemantics(
        find.byType(PersonTile),
      );
      expect(personTileSemantics.label, isNot(contains('GL')));

      final excludeSemantics = tester.widget<ExcludeSemantics>(
        find.ancestor(
          of: find.byType(InitialsAvatar),
          matching: find.byType(ExcludeSemantics),
        ),
      );
      expect(excludeSemantics.excluding, isTrue);

      handle.dispose();
    });
  });
}
