@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Goldens lock the official Google/Apple brand marks so an accidental edit to
// the embedded SVG path data is caught. The marks are pure vector (no text),
// so these render deterministically without bundled fonts.
void main() {
  testWidgets('GoogleLogo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
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

  testWidgets('AppleLogo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AppleLogo(size: 96)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AppleLogo),
      matchesGoldenFile('goldens/apple_logo.png'),
    );
  });
}
