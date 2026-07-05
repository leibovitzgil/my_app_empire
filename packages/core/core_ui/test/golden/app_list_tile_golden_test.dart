@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes.
final ThemeData _theme = AppTheme.testTheme();
final ThemeData _darkTheme = AppTheme.testTheme(brightness: Brightness.dark);

Widget _wrap(ThemeData theme, Widget child) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, child: child)),
    ),
  );
}

void main() {
  group('core_ui goldens', () {
    testWidgets('AppListTile (default, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _theme,
          const AppListTile(
            leading: Icon(Icons.check_circle_outline),
            title: Text('Buy milk'),
            subtitle: Text('Added by Gil'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppListTile),
        matchesGoldenFile('goldens/app_list_tile_default_light.png'),
      );
    });

    testWidgets('AppListTile (default, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _darkTheme,
          const AppListTile(
            leading: Icon(Icons.check_circle_outline),
            title: Text('Buy milk'),
            subtitle: Text('Added by Gil'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppListTile),
        matchesGoldenFile('goldens/app_list_tile_default_dark.png'),
      );
    });

    testWidgets('AppListTile (with trailing, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _theme,
          const AppListTile(
            leading: Icon(Icons.check_circle_outline),
            title: Text('Buy milk'),
            subtitle: Text('Added by Gil'),
            trailing: Icon(Icons.chevron_right),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppListTile),
        matchesGoldenFile('goldens/app_list_tile_with_trailing_light.png'),
      );
    });

    testWidgets('AppListTile (with trailing, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _darkTheme,
          const AppListTile(
            leading: Icon(Icons.check_circle_outline),
            title: Text('Buy milk'),
            subtitle: Text('Added by Gil'),
            trailing: Icon(Icons.chevron_right),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppListTile),
        matchesGoldenFile('goldens/app_list_tile_with_trailing_dark.png'),
      );
    });

    testWidgets('PersonTile (default, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _theme,
          const PersonTile(
            initials: 'GL',
            color: Colors.indigo,
            name: 'Gil Leibovich',
            subtitle: 'gil@example.com',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PersonTile),
        matchesGoldenFile('goldens/person_tile_default_light.png'),
      );
    });

    testWidgets('PersonTile (default, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _darkTheme,
          const PersonTile(
            initials: 'GL',
            color: Colors.indigo,
            name: 'Gil Leibovich',
            subtitle: 'gil@example.com',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PersonTile),
        matchesGoldenFile('goldens/person_tile_default_dark.png'),
      );
    });

    testWidgets('PersonTile (remove trailing, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _theme,
          PersonTile(
            initials: 'AM',
            color: Colors.teal,
            name: 'Alex Morgan',
            subtitle: 'alex@example.com',
            trailing: IconButton(
              tooltip: 'Remove Alex Morgan',
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PersonTile),
        matchesGoldenFile('goldens/person_tile_remove_trailing_light.png'),
      );
    });

    testWidgets('PersonTile (remove trailing, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _darkTheme,
          PersonTile(
            initials: 'AM',
            color: Colors.teal,
            name: 'Alex Morgan',
            subtitle: 'alex@example.com',
            trailing: IconButton(
              tooltip: 'Remove Alex Morgan',
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PersonTile),
        matchesGoldenFile('goldens/person_tile_remove_trailing_dark.png'),
      );
    });
  });
}
