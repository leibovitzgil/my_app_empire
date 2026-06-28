import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecentlyDeletedScreen', () {
    const me = GrocerySeed.you;
    late InMemoryGroceryRepository repo;

    setUp(() => repo = InMemoryGroceryRepository(demo: false));
    tearDown(() async => repo.dispose());

    Widget host() => MaterialApp(
      home: BlocProvider(
        create: (_) => ListBloc(repository: repo, currentUser: me),
        child: const RecentlyDeletedScreen(),
      ),
    );

    testWidgets('empty state shows guidance (F6)', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('Nothing deleted recently'), findsOneWidget);
    });

    testWidgets('lists a tombstoned item with a Restore action (F6)', (
      tester,
    ) async {
      await repo.deleteItem('seed_milk', by: me);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
    });
  });
}
