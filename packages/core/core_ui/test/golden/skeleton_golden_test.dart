@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes.
//
// Every golden here passes shimmer: false — a repeating animation never
// settles, so pumpAndSettle would hang and a mid-animation frame would be
// flaky. shimmer: true is left to widget tests, not goldens.
final ThemeData _theme = AppTheme.testTheme();
final ThemeData _darkTheme = AppTheme.testTheme(brightness: Brightness.dark);

void main() {
  group('core_ui goldens', () {
    testWidgets('SkeletonBox (light)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          home: const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: SkeletonBox(width: 200, shimmer: false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SkeletonBox),
        matchesGoldenFile('goldens/skeleton_box_default_light.png'),
      );
    });

    testWidgets('SkeletonBox (dark)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _darkTheme,
          home: const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: SkeletonBox(width: 200, shimmer: false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SkeletonBox),
        matchesGoldenFile('goldens/skeleton_box_default_dark.png'),
      );
    });

    testWidgets('SkeletonList (light)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(24),
              child: SkeletonList(shimmer: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SkeletonList),
        matchesGoldenFile('goldens/skeleton_list_default_light.png'),
      );
    });

    testWidgets('SkeletonList (dark)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _darkTheme,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(24),
              child: SkeletonList(shimmer: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SkeletonList),
        matchesGoldenFile('goldens/skeleton_list_default_dark.png'),
      );
    });
  });
}
