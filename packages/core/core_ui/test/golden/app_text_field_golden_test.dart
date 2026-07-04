@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes.
final ThemeData _theme = AppTheme.testTheme();
final ThemeData _darkTheme = AppTheme.testTheme(brightness: Brightness.dark);

// Focused-state golden is intentionally skipped: capturing a stable focus
// ring requires pumping platform focus/text-input plumbing that doesn't
// settle deterministically in a widget test, per the plan's guidance to skip
// rather than force it.

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
    testWidgets('AppTextField (default, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(_theme, const AppTextField(label: 'Email')),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppTextField),
        matchesGoldenFile('goldens/app_text_field_default_light.png'),
      );
    });

    testWidgets('AppTextField (default, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(_darkTheme, const AppTextField(label: 'Email')),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppTextField),
        matchesGoldenFile('goldens/app_text_field_default_dark.png'),
      );
    });

    testWidgets('AppTextField (error, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _theme,
          const AppTextField(label: 'Email', errorText: 'Required'),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppTextField),
        matchesGoldenFile('goldens/app_text_field_error_light.png'),
      );
    });

    testWidgets('AppTextField (error, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _darkTheme,
          const AppTextField(label: 'Email', errorText: 'Required'),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppTextField),
        matchesGoldenFile('goldens/app_text_field_error_dark.png'),
      );
    });

    testWidgets('AppTextField (disabled, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(_theme, const AppTextField(label: 'Email', enabled: false)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppTextField),
        matchesGoldenFile('goldens/app_text_field_disabled_light.png'),
      );
    });

    testWidgets('AppTextField (disabled, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(_darkTheme, const AppTextField(label: 'Email', enabled: false)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppTextField),
        matchesGoldenFile('goldens/app_text_field_disabled_dark.png'),
      );
    });
  });
}
