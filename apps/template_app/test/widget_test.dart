import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:template_app/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    // Note: In our modified app, we use a PrimaryButton labeled 'Increment'
    await tester.tap(find.text('Increment'));
    await tester.pump();

    // Verify that our counter has incremented.
    // Note: We added a delay, so we need to pump for the duration.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
