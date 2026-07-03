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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(width: 240, child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('core_ui goldens', () {
    testWidgets('AppCard (default, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(_theme, AppCard(onTap: () {}, child: const Text('Card'))),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppCard),
        matchesGoldenFile('goldens/app_card_default_light.png'),
      );
    });

    testWidgets('AppCard (default, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(_darkTheme, AppCard(onTap: () {}, child: const Text('Card'))),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppCard),
        matchesGoldenFile('goldens/app_card_default_dark.png'),
      );
    });

    testWidgets('AppCard (selected, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _theme,
          AppCard(selected: true, onTap: () {}, child: const Text('Card')),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppCard),
        matchesGoldenFile('goldens/app_card_selected_light.png'),
      );
    });

    testWidgets('AppCard (selected, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _darkTheme,
          AppCard(selected: true, onTap: () {}, child: const Text('Card')),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppCard),
        matchesGoldenFile('goldens/app_card_selected_dark.png'),
      );
    });

    testWidgets('AppCard (disabled, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _theme,
          AppCard(enabled: false, onTap: () {}, child: const Text('Card')),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppCard),
        matchesGoldenFile('goldens/app_card_disabled_light.png'),
      );
    });

    testWidgets('AppCard (disabled, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _darkTheme,
          AppCard(enabled: false, onTap: () {}, child: const Text('Card')),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppCard),
        matchesGoldenFile('goldens/app_card_disabled_dark.png'),
      );
    });
  });
}
