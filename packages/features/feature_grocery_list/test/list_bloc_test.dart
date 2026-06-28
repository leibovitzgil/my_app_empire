import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGroceryRepository extends Mock implements GroceryRepository {}

void main() {
  group('ListBloc', () {
    const me = GrocerySeed.you;
    final seed = GrocerySeed.initialList(DateTime(2026, 6, 28, 12));
    late MockGroceryRepository repo;
    late StreamController<GroceryList> controller;

    setUpAll(() => registerFallbackValue(me));

    setUp(() {
      repo = MockGroceryRepository();
      controller = StreamController<GroceryList>.broadcast();
      when(repo.watchList).thenAnswer((_) => controller.stream);
      when(
        () => repo.addItem(any(), by: any(named: 'by')),
      ).thenAnswer((_) async => Success<GroceryItem>(seed.items.first));
      when(
        () => repo.cycleStatus(any(), by: any(named: 'by')),
      ).thenAnswer((_) async => const Success<void>(null));
    });

    tearDown(() => controller.close());

    test('initial state is loading', () {
      expect(
        ListBloc(repository: repo, currentUser: me).state.status,
        ListStatus.loading,
      );
    });

    blocTest<ListBloc, ListState>(
      'emits ready with the list when the stream emits (F1 snapshot)',
      build: () => ListBloc(repository: repo, currentUser: me),
      act: (_) => controller.add(seed),
      expect: () => [
        isA<ListState>()
            .having((s) => s.status, 'status', ListStatus.ready)
            .having((s) => s.list, 'list', seed),
      ],
    );

    blocTest<ListBloc, ListState>(
      'ItemAdded forwards to repository.addItem as the current user (F5)',
      build: () => ListBloc(repository: repo, currentUser: me),
      act: (bloc) => bloc.add(const ItemAdded('Yogurt')),
      verify: (_) => verify(() => repo.addItem('Yogurt', by: me)).called(1),
    );

    blocTest<ListBloc, ListState>(
      'StatusCycled forwards to repository.cycleStatus (F2)',
      build: () => ListBloc(repository: repo, currentUser: me),
      act: (bloc) => bloc.add(const StatusCycled('seed_milk')),
      verify: (_) =>
          verify(() => repo.cycleStatus('seed_milk', by: me)).called(1),
    );

    blocTest<ListBloc, ListState>(
      'FlagsOnlyToggled flips the filter without touching the repo (F4)',
      build: () => ListBloc(repository: repo, currentUser: me),
      act: (bloc) => bloc.add(const FlagsOnlyToggled()),
      expect: () => [
        isA<ListState>().having((s) => s.flagsOnly, 'flagsOnly', true),
      ],
    );
  });
}
