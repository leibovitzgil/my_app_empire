@Tags(['golden'])
library;

import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes.
final ThemeData _theme = AppTheme.testTheme();
final ThemeData _darkTheme = AppTheme.testTheme(brightness: Brightness.dark);

Widget _wrap(ThemeData theme, {required bool isDestructive}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () => unawaited(
              confirmDialog(
                context,
                title: isDestructive ? 'Delete account?' : 'Discard draft?',
                message: isDestructive
                    ? 'This cannot be undone.'
                    : 'Your changes will be lost.',
                confirmLabel: isDestructive ? 'Delete' : 'Discard',
                isDestructive: isDestructive,
              ),
            ),
            child: const Text('Open'),
          );
        },
      ),
    ),
  );
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byType(ElevatedButton));
  // The dialog has an enter animation; a fixed pump past its (short) default
  // transition duration captures a settled frame without pumpAndSettle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('core_ui goldens', () {
    testWidgets('confirmDialog (default, light)', (tester) async {
      await tester.pumpWidget(_wrap(_theme, isDestructive: false));
      await _openDialog(tester);
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('goldens/confirm_dialog_default_light.png'),
      );
    });

    testWidgets('confirmDialog (default, dark)', (tester) async {
      await tester.pumpWidget(_wrap(_darkTheme, isDestructive: false));
      await _openDialog(tester);
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('goldens/confirm_dialog_default_dark.png'),
      );
    });

    testWidgets('confirmDialog (destructive, light)', (tester) async {
      await tester.pumpWidget(_wrap(_theme, isDestructive: true));
      await _openDialog(tester);
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('goldens/confirm_dialog_destructive_light.png'),
      );
    });

    testWidgets('confirmDialog (destructive, dark)', (tester) async {
      await tester.pumpWidget(_wrap(_darkTheme, isDestructive: true));
      await _openDialog(tester);
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('goldens/confirm_dialog_destructive_dark.png'),
      );
    });
  });
}
