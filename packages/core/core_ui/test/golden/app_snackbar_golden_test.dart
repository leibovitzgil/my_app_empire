@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes.
final ThemeData _theme = AppTheme.testTheme();
final ThemeData _darkTheme = AppTheme.testTheme(brightness: Brightness.dark);

Widget _wrap(ThemeData theme, AppSnackbarVariant variant, String message) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () =>
                AppSnackbar.show(context, message: message, variant: variant),
            child: const Text('Trigger'),
          );
        },
      ),
    ),
  );
}

Future<void> _showSnackbar(WidgetTester tester) async {
  await tester.tap(find.byType(ElevatedButton));
  // A snackbar has an enter animation that never fully settles in a way
  // pumpAndSettle likes; a fixed pump captures it mid/settled, matching the
  // convention used by other overlay goldens in this suite.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('core_ui goldens', () {
    testWidgets('AppSnackbar (success, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(_theme, AppSnackbarVariant.success, 'Saved successfully'),
      );
      await _showSnackbar(tester);
      await expectLater(
        find.byType(SnackBar),
        matchesGoldenFile('goldens/app_snackbar_success_light.png'),
      );
    });

    testWidgets('AppSnackbar (success, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(_darkTheme, AppSnackbarVariant.success, 'Saved successfully'),
      );
      await _showSnackbar(tester);
      await expectLater(
        find.byType(SnackBar),
        matchesGoldenFile('goldens/app_snackbar_success_dark.png'),
      );
    });

    testWidgets('AppSnackbar (error, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(_theme, AppSnackbarVariant.error, 'Something went wrong'),
      );
      await _showSnackbar(tester);
      await expectLater(
        find.byType(SnackBar),
        matchesGoldenFile('goldens/app_snackbar_error_light.png'),
      );
    });

    testWidgets('AppSnackbar (error, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(_darkTheme, AppSnackbarVariant.error, 'Something went wrong'),
      );
      await _showSnackbar(tester);
      await expectLater(
        find.byType(SnackBar),
        matchesGoldenFile('goldens/app_snackbar_error_dark.png'),
      );
    });

    testWidgets('AppSnackbar (info, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(_theme, AppSnackbarVariant.info, 'Heads up'),
      );
      await _showSnackbar(tester);
      await expectLater(
        find.byType(SnackBar),
        matchesGoldenFile('goldens/app_snackbar_info_light.png'),
      );
    });

    testWidgets('AppSnackbar (info, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(_darkTheme, AppSnackbarVariant.info, 'Heads up'),
      );
      await _showSnackbar(tester);
      await expectLater(
        find.byType(SnackBar),
        matchesGoldenFile('goldens/app_snackbar_info_dark.png'),
      );
    });
  });
}
