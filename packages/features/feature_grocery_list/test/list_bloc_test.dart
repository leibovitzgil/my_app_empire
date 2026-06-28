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

    setUpAll(() {
      registerFallbackValue(me);
      registerFallbackValue(ItemStatus.needed);
      registerFallbackValue(ItemFlag.urgent);
    });

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
      when(
        () => repo.deleteItem(any(), by: any(named: 'by')),
      ).thenAnswer((_) async => const Success<void>(null));
      when(
        () => repo.setFlag(any(), any(), by: any(named: 'by')),
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

    blocTest<ListBloc, ListState>(
      'emits error when the list stream errors',
      build: () => ListBloc(repository: repo, currentUser: me),
      act: (_) => controller.addError(Exception('boom')),
      expect: () => [
        isA<ListState>().having((s) => s.status, 'status', ListStatus.error),
      ],
    );

    blocTest<ListBloc, ListState>(
      'surfaces a transient actionError when a mutation fails (F7 seam)',
      build: () {
        when(
          () => repo.cycleStatus(any(), by: any(named: 'by')),
        ).thenAnswer((_) async => ResultFailure<void>(Exception('nope')));
        return ListBloc(repository: repo, currentUser: me);
      },
      act: (bloc) => bloc.add(const StatusCycled('x')),
      expect: () => [
        isA<ListState>().having((s) => s.actionError, 'actionError', isNotNull),
      ],
    );

    blocTest<ListBloc, ListState>(
      'ListRetryRequested resets to loading and re-subscribes',
      build: () => ListBloc(repository: repo, currentUser: me),
      act: (bloc) => bloc.add(const ListRetryRequested()),
      expect: () => [
        isA<ListState>().having((s) => s.status, 'status', ListStatus.loading),
      ],
      verify: (_) => verify(repo.watchList).called(greaterThanOrEqualTo(2)),
    );

    blocTest<ListBloc, ListState>(
      'ItemDeleted forwards to repository.deleteItem (F6)',
      build: () => ListBloc(repository: repo, currentUser: me),
      act: (bloc) => bloc.add(const ItemDeleted('seed_milk')),
      verify: (_) =>
          verify(() => repo.deleteItem('seed_milk', by: me)).called(1),
    );

    blocTest<ListBloc, ListState>(
      'ItemFlagged forwards to repository.setFlag (F4)',
      build: () => ListBloc(repository: repo, currentUser: me),
      act: (bloc) =>
          bloc.add(const ItemFlagged('seed_milk', ItemFlag.outOfStock)),
      verify: (_) => verify(
        () => repo.setFlag('seed_milk', ItemFlag.outOfStock, by: me),
      ).called(1),
    );
  });
}
