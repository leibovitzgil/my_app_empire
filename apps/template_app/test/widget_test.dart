import 'package:flutter_test/flutter_test.dart';

import 'package:template_app/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the button (labeled 'Increment') and show the loading state.
    await tester.tap(find.text('Increment'));
    await tester.pump();

    // The increment is delayed by 1s; advance the clock, then settle the
    // button's fade-in animation so no timers remain pending at teardown.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
