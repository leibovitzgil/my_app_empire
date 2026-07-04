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
    testWidgets('AppTextButton (enabled, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(_theme, AppTextButton(label: 'Skip', onPressed: () {})),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppTextButton),
        matchesGoldenFile('goldens/app_text_button_enabled_light.png'),
      );
    });

    testWidgets('AppTextButton (enabled, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(_darkTheme, AppTextButton(label: 'Skip', onPressed: () {})),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppTextButton),
        matchesGoldenFile('goldens/app_text_button_enabled_dark.png'),
      );
    });

    testWidgets('AppTextButton (loading, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _theme,
          const AppTextButton(
            label: 'Skip',
            onPressed: null,
            isLoading: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(AppTextButton),
        matchesGoldenFile('goldens/app_text_button_loading_light.png'),
      );
    });

    testWidgets('AppTextButton (loading, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _darkTheme,
          const AppTextButton(
            label: 'Skip',
            onPressed: null,
            isLoading: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(AppTextButton),
        matchesGoldenFile('goldens/app_text_button_loading_dark.png'),
      );
    });

    testWidgets('AppTextButton (destructive, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _theme,
          AppTextButton(
            label: 'Delete',
            onPressed: () {},
            isDestructive: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppTextButton),
        matchesGoldenFile('goldens/app_text_button_destructive_light.png'),
      );
    });

    testWidgets('AppTextButton (destructive, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _darkTheme,
          AppTextButton(
            label: 'Delete',
            onPressed: () {},
            isDestructive: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppTextButton),
        matchesGoldenFile('goldens/app_text_button_destructive_dark.png'),
      );
    });
  });
}
