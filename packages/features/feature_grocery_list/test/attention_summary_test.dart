import 'package:feature_grocery_list/src/ui/attention_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttentionSummary', () {
    Widget host(int count, {bool flagsOnly = false, VoidCallback? onTap}) =>
        MaterialApp(
          home: Scaffold(
            body: AttentionSummary(
              count: count,
              flagsOnly: flagsOnly,
              onTap: onTap ?? () {},
            ),
          ),
        );

    testWidgets('hidden when count 0 and filter off (F4)', (tester) async {
      await tester.pumpWidget(host(0));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('shows a pluralized count (F4)', (tester) async {
      await tester.pumpWidget(host(2));
      expect(find.text('2 items need attention'), findsOneWidget);
    });

    testWidgets('tapping toggles the filter (F4)', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(host(1, onTap: () => tapped++));
      await tester.tap(find.byType(InkWell));
      expect(tapped, 1);
    });
  });
}
