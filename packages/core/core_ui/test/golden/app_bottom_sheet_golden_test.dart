@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes.
final ThemeData _theme = AppTheme.testTheme();
final ThemeData _darkTheme = AppTheme.testTheme(brightness: Brightness.dark);

Widget _wrap(ThemeData theme, {required String? title}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () => AppBottomSheet.show<void>(
              context,
              title: title,
              builder: (sheetContext) => const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.lg),
                child: Text('Sheet body content goes here.'),
              ),
            ),
            child: const Text('Open'),
          );
        },
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(ElevatedButton));
  // The sheet has an enter animation; a fixed pump past its (short) default
  // transition duration captures a settled frame without pumpAndSettle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('core_ui goldens', () {
    testWidgets('AppBottomSheet (with title, light)', (tester) async {
      await tester.pumpWidget(_wrap(_theme, title: 'Confirm pickup'));
      await _openSheet(tester);
      await expectLater(
        find.byType(BottomSheet),
        matchesGoldenFile('goldens/app_bottom_sheet_with_title_light.png'),
      );
    });

    testWidgets('AppBottomSheet (with title, dark)', (tester) async {
      await tester.pumpWidget(_wrap(_darkTheme, title: 'Confirm pickup'));
      await _openSheet(tester);
      await expectLater(
        find.byType(BottomSheet),
        matchesGoldenFile('goldens/app_bottom_sheet_with_title_dark.png'),
      );
    });

    testWidgets('AppBottomSheet (no title, light)', (tester) async {
      await tester.pumpWidget(_wrap(_theme, title: null));
      await _openSheet(tester);
      await expectLater(
        find.byType(BottomSheet),
        matchesGoldenFile('goldens/app_bottom_sheet_no_title_light.png'),
      );
    });

    testWidgets('AppBottomSheet (no title, dark)', (tester) async {
      await tester.pumpWidget(_wrap(_darkTheme, title: null));
      await _openSheet(tester);
      await expectLater(
        find.byType(BottomSheet),
        matchesGoldenFile('goldens/app_bottom_sheet_no_title_dark.png'),
      );
    });
  });
}
