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
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

void main() {
  group('core_ui goldens', () {
    testWidgets('SectionHeader (light)', (tester) async {
      await tester.pumpWidget(_wrap(_theme, const SectionHeader('Profile')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SectionHeader),
        matchesGoldenFile('goldens/section_header_light.png'),
      );
    });

    testWidgets('SectionHeader (dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(_darkTheme, const SectionHeader('Profile')),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SectionHeader),
        matchesGoldenFile('goldens/section_header_dark.png'),
      );
    });
  });
}
