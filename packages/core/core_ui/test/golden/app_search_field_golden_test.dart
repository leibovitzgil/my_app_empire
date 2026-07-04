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
      body: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  );
}

void main() {
  group('core_ui goldens', () {
    testWidgets('AppSearchField (empty, light)', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_theme, AppSearchField(controller: controller)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppSearchField),
        matchesGoldenFile('goldens/app_search_field_empty_light.png'),
      );
    });

    testWidgets('AppSearchField (empty, dark)', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_darkTheme, AppSearchField(controller: controller)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppSearchField),
        matchesGoldenFile('goldens/app_search_field_empty_dark.png'),
      );
    });

    testWidgets('AppSearchField (has text, light)', (tester) async {
      final controller = TextEditingController(text: 'milk');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_theme, AppSearchField(controller: controller)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppSearchField),
        matchesGoldenFile('goldens/app_search_field_has_text_light.png'),
      );
    });

    testWidgets('AppSearchField (has text, dark)', (tester) async {
      final controller = TextEditingController(text: 'milk');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_darkTheme, AppSearchField(controller: controller)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppSearchField),
        matchesGoldenFile('goldens/app_search_field_has_text_dark.png'),
      );
    });
  });
}
