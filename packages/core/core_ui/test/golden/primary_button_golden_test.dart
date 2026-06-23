@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A network-free theme (AppTheme pulls google_fonts, which fetches at runtime).
final _theme = ThemeData(useMaterial3: true);

void main() {
  group('core_ui goldens', () {
    testWidgets('PrimaryButton (enabled)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PrimaryButton(label: 'Continue', onPressed: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PrimaryButton),
        matchesGoldenFile('goldens/primary_button_enabled.png'),
      );
    });

    testWidgets('PrimaryButton (loading)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          home: const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: PrimaryButton(
                  label: 'Continue',
                  onPressed: null,
                  isLoading: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(PrimaryButton),
        matchesGoldenFile('goldens/primary_button_loading.png'),
      );
    });
  });
}
