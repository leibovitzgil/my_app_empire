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
    testWidgets('EmptyStateView (default, light)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          home: const Scaffold(
            body: EmptyStateView(
              icon: Icons.shopping_basket_outlined,
              title: 'Your list is empty',
              message: 'Add the first item below',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(EmptyStateView),
        matchesGoldenFile('goldens/empty_state_view_default_light.png'),
      );
    });

    testWidgets('EmptyStateView (default, dark)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _darkTheme,
          home: const Scaffold(
            body: EmptyStateView(
              icon: Icons.shopping_basket_outlined,
              title: 'Your list is empty',
              message: 'Add the first item below',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(EmptyStateView),
        matchesGoldenFile('goldens/empty_state_view_default_dark.png'),
      );
    });
  });
}
