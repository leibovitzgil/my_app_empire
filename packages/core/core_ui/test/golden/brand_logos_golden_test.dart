@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Golden locks the official Google brand mark so an accidental edit to the
// embedded SVG path data is caught. The mark is pure vector (no text), so it
// renders deterministically without bundled fonts.
void main() {
  testWidgets('GoogleLogo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.testTheme(),
        home: const Scaffold(
          body: Center(child: GoogleLogo(size: 96)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(GoogleLogo),
      matchesGoldenFile('goldens/google_logo.png'),
    );
  });
}
