@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes.
final ThemeData _theme = AppTheme.testTheme();
final ThemeData _darkTheme = AppTheme.testTheme(brightness: Brightness.dark);

// NOTE: in this headless test environment, MaterialIcons glyphs (and any
// non-ASCII text) fall back to an identical "tofu" box regardless of
// codepoint — confirmed by probing two different Icons and diffing bytes.
// That means the obscured/revealed goldens below are pixel-identical: the
// icon swap and dot-masking aren't visually distinguishable here even though
// the underlying widget state genuinely differs (see the toggle behavior
// covered by app_password_field_test.dart's non-golden tests). Kept anyway
// per the plan's coverage list — they still guard structure/layout — but
// don't expect a diff between the two pairs.

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
    testWidgets('AppPasswordField (obscured, light)', (tester) async {
      final controller = TextEditingController(text: 'hunter2');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_theme, AppPasswordField(controller: controller)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppPasswordField),
        matchesGoldenFile('goldens/app_password_field_obscured_light.png'),
      );
    });

    testWidgets('AppPasswordField (obscured, dark)', (tester) async {
      final controller = TextEditingController(text: 'hunter2');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_darkTheme, AppPasswordField(controller: controller)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppPasswordField),
        matchesGoldenFile('goldens/app_password_field_obscured_dark.png'),
      );
    });

    testWidgets('AppPasswordField (revealed, light)', (tester) async {
      final controller = TextEditingController(text: 'hunter2');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_theme, AppPasswordField(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppPasswordField),
        matchesGoldenFile('goldens/app_password_field_revealed_light.png'),
      );
    });

    testWidgets('AppPasswordField (revealed, dark)', (tester) async {
      final controller = TextEditingController(text: 'hunter2');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_darkTheme, AppPasswordField(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppPasswordField),
        matchesGoldenFile('goldens/app_password_field_revealed_dark.png'),
      );
    });
  });
}
