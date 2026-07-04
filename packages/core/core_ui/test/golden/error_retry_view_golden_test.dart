@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes.
final ThemeData _theme = AppTheme.testTheme();
final ThemeData _darkTheme = AppTheme.testTheme(brightness: Brightness.dark);

void main() {
  group('core_ui goldens', () {
    testWidgets('ErrorRetryView (default, light)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          home: Scaffold(
            body: ErrorRetryView(
              icon: Icons.wifi_off,
              title: "Couldn't load the list",
              message: 'Check your connection and try again.',
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ErrorRetryView),
        matchesGoldenFile('goldens/error_retry_view_default_light.png'),
      );
    });

    testWidgets('ErrorRetryView (default, dark)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _darkTheme,
          home: Scaffold(
            body: ErrorRetryView(
              icon: Icons.wifi_off,
              title: "Couldn't load the list",
              message: 'Check your connection and try again.',
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ErrorRetryView),
        matchesGoldenFile('goldens/error_retry_view_default_dark.png'),
      );
    });
  });
}
