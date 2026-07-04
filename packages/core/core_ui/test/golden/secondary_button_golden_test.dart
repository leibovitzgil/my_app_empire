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
      body: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    ),
  );
}

void main() {
  group('core_ui goldens', () {
    testWidgets('SecondaryButton (enabled, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(_theme, SecondaryButton(label: 'Cancel', onPressed: () {})),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SecondaryButton),
        matchesGoldenFile('goldens/secondary_button_enabled_light.png'),
      );
    });

    testWidgets('SecondaryButton (enabled, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(_darkTheme, SecondaryButton(label: 'Cancel', onPressed: () {})),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SecondaryButton),
        matchesGoldenFile('goldens/secondary_button_enabled_dark.png'),
      );
    });

    testWidgets('SecondaryButton (loading, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _theme,
          const SecondaryButton(
            label: 'Cancel',
            onPressed: null,
            isLoading: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(SecondaryButton),
        matchesGoldenFile('goldens/secondary_button_loading_light.png'),
      );
    });

    testWidgets('SecondaryButton (loading, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _darkTheme,
          const SecondaryButton(
            label: 'Cancel',
            onPressed: null,
            isLoading: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(SecondaryButton),
        matchesGoldenFile('goldens/secondary_button_loading_dark.png'),
      );
    });

    testWidgets('SecondaryButton (destructive, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _theme,
          SecondaryButton(
            label: 'Delete',
            onPressed: () {},
            isDestructive: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SecondaryButton),
        matchesGoldenFile('goldens/secondary_button_destructive_light.png'),
      );
    });

    testWidgets('SecondaryButton (destructive, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _darkTheme,
          SecondaryButton(
            label: 'Delete',
            onPressed: () {},
            isDestructive: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SecondaryButton),
        matchesGoldenFile('goldens/secondary_button_destructive_dark.png'),
      );
    });
  });
}
