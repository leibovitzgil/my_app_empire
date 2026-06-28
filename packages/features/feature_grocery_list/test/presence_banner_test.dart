import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:feature_grocery_list/src/ui/presence_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PresenceBanner', () {
    const me = GrocerySeed.you;
    final now = DateTime(2026, 6, 28, 12);

    Widget host(List<Shopper> shoppers) => MaterialApp(
      home: Scaffold(
        body: PresenceBanner(shoppers: shoppers, currentUser: me),
      ),
    );

    testWidgets('renders nothing when no one is shopping (F3)', (tester) async {
      await tester.pumpWidget(host(const <Shopper>[]));
      expect(find.textContaining('shopping'), findsNothing);
    });

    testWidgets('shows a single other shopper by name (F3)', (tester) async {
      await tester.pumpWidget(
        host([Shopper(collaborator: GrocerySeed.dana, since: now)]),
      );
      expect(find.text('Dana is shopping'), findsOneWidget);
    });

    testWidgets('renders the current user as "You" (F3)', (tester) async {
      await tester.pumpWidget(host([Shopper(collaborator: me, since: now)]));
      expect(find.text('You are shopping'), findsOneWidget);
    });
  });
}
