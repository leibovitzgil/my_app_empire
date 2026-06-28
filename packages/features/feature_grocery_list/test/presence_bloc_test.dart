import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPresenceRepository extends Mock implements PresenceRepository {}

void main() {
  group('PresenceBloc', () {
    const me = GrocerySeed.you;
    final dana = Shopper(
      collaborator: GrocerySeed.dana,
      since: DateTime(2026, 6, 28, 12),
    );
    late MockPresenceRepository repo;
    late StreamController<List<Shopper>> controller;

    setUpAll(() => registerFallbackValue(me));

    setUp(() {
      repo = MockPresenceRepository();
      controller = StreamController<List<Shopper>>.broadcast();
      when(repo.watchShoppers).thenAnswer((_) => controller.stream);
      when(() => repo.enter(any())).thenAnswer((_) async {});
      when(() => repo.leave(any())).thenAnswer((_) async {});
      when(() => repo.heartbeat(any())).thenAnswer((_) async {});
    });

    tearDown(() => controller.close());

    test('initial state is inactive', () {
      expect(
        PresenceBloc(repository: repo, currentUser: me).state.isActive,
        isFalse,
      );
    });

    blocTest<PresenceBloc, PresenceState>(
      'reflects shoppers arriving on the stream (F3)',
      build: () => PresenceBloc(repository: repo, currentUser: me),
      act: (_) => controller.add([dana]),
      expect: () => [
        isA<PresenceState>().having((s) => s.isActive, 'isActive', true),
      ],
    );

    blocTest<PresenceBloc, PresenceState>(
      'ShoppingEntered enters the current user',
      build: () => PresenceBloc(repository: repo, currentUser: me),
      act: (bloc) => bloc.add(const ShoppingEntered()),
      verify: (_) => verify(() => repo.enter(me)).called(1),
    );

    blocTest<PresenceBloc, PresenceState>(
      'ShoppingLeft leaves the current user',
      build: () => PresenceBloc(repository: repo, currentUser: me),
      act: (bloc) => bloc.add(const ShoppingLeft()),
      // close() also leaves, so assert at-least-once rather than exactly once.
      verify: (_) =>
          verify(() => repo.leave(me.id)).called(greaterThanOrEqualTo(1)),
    );

    blocTest<PresenceBloc, PresenceState>(
      'an empty shopper set clears presence — no stale state (F3)',
      build: () => PresenceBloc(repository: repo, currentUser: me),
      act: (bloc) {
        controller
          ..add([dana])
          ..add(const <Shopper>[]);
      },
      expect: () => [
        isA<PresenceState>().having((s) => s.isActive, 'isActive', true),
        isA<PresenceState>().having((s) => s.isActive, 'isActive', false),
      ],
    );

    blocTest<PresenceBloc, PresenceState>(
      'heartbeats periodically while in shopping mode (F3)',
      build: () => PresenceBloc(
        repository: repo,
        currentUser: me,
        heartbeatInterval: const Duration(milliseconds: 30),
      ),
      act: (bloc) async {
        bloc.add(const ShoppingEntered());
        await Future<void>.delayed(const Duration(milliseconds: 130));
      },
      verify: (_) =>
          verify(() => repo.heartbeat(me.id)).called(greaterThanOrEqualTo(2)),
    );
  });
}
