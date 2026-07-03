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
    testWidgets('LoadingView (default, light)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          home: const Scaffold(body: LoadingView()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(LoadingView),
        matchesGoldenFile('goldens/loading_view_default_light.png'),
      );
    });

    testWidgets('LoadingView (default, dark)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _darkTheme,
          home: const Scaffold(body: LoadingView()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(LoadingView),
        matchesGoldenFile('goldens/loading_view_default_dark.png'),
      );
    });

    testWidgets('LoadingView (with label, light)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          home: const Scaffold(
            body: LoadingView(label: 'Loading your list…'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(LoadingView),
        matchesGoldenFile('goldens/loading_view_with_label_light.png'),
      );
    });

    testWidgets('LoadingView (with label, dark)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _darkTheme,
          home: const Scaffold(
            body: LoadingView(label: 'Loading your list…'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(LoadingView),
        matchesGoldenFile('goldens/loading_view_with_label_dark.png'),
      );
    });
  });
}
