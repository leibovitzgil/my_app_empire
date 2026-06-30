import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShareSheet', () {
    final now = DateTime(2026, 6, 28, 12);
    late InMemoryGroceryRepository repo;

    setUp(() {
      repo = InMemoryGroceryRepository(demo: false, clock: () => now);
    });
    tearDown(() async => repo.dispose());

    Future<void> pumpSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // Provide the bloc via BlocProvider so it is closed on unmount,
            // mirroring the app (the page owns the bloc and hands it to the
            // sheet via BlocProvider.value). Creating the bloc and closing it
            // in a teardown instead deadlocks the in-memory stream's cancel
            // under the widget test's fake-async clock.
            body: BlocProvider<MembersBloc>(
              create: (_) =>
                  MembersBloc(repository: repo, currentUser: GrocerySeed.you),
              child: const ShareSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the seeded roster with roles', (tester) async {
      await pumpSheet(tester);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Dana'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
    });

    testWidgets('Invite is disabled until the email looks valid', (
      tester,
    ) async {
      await pumpSheet(tester);
      FilledButton button() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Invite'),
      );
      expect(button().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'pat.kim@example.com');
      await tester.pump();
      expect(button().onPressed, isNotNull);
    });

    testWidgets('inviting by email adds a pending member to the roster', (
      tester,
    ) async {
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'pat.kim@example.com');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Invite'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Pat Kim'), findsOneWidget);
      expect(find.text('Invited · pending'), findsOneWidget);
    });
  });
}
