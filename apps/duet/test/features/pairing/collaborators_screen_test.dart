import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPieceRepository extends Mock implements PieceRepository {}

void main() {
  group('CollaboratorsScreen', () {
    const ownerId = 'owner-1';
    const collaboratorA = Collaborator(
      uid: 'a',
      name: 'Alex Morgan',
      email: 'alex@example.com',
    );
    const collaboratorB = Collaborator(
      uid: 'b',
      name: 'Bo Kim',
      email: 'bo@example.com',
    );

    late MockPieceRepository pieceRepository;
    late StreamController<List<Piece>> controller;

    Piece piece(List<Collaborator> collaborators) => Piece(
      id: 'p1',
      title: 'Nocturne',
      basePdfChecksum: 'c',
      basePdfPath: '/tmp/p.pdf',
      ownerId: ownerId,
      ownerName: 'Jane Doe',
      collaborators: collaborators,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    setUp(() {
      pieceRepository = MockPieceRepository();
      controller = StreamController<List<Piece>>.broadcast();
      when(pieceRepository.watchPieces).thenAnswer((_) => controller.stream);
    });
    tearDown(() => controller.close());

    Future<void> pumpScreen(WidgetTester tester, String currentUserId) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CollaboratorsPage(
            pieceRepository: pieceRepository,
            pieceId: 'p1',
            currentUserId: currentUserId,
          ),
        ),
      );
      controller.add([
        piece(const [collaboratorA, collaboratorB]),
      ]);
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'owner-viewer sees a remove affordance on every collaborator row, and '
      'no Leave',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpScreen(tester, ownerId);

        expect(find.text('Alex Morgan'), findsOneWidget);
        expect(find.text('Bo Kim'), findsOneWidget);
        expect(find.byIcon(Icons.person_remove_outlined), findsNWidgets(2));
        expect(find.byIcon(Icons.logout), findsNothing);
        expect(find.byTooltip('Remove Alex Morgan'), findsOneWidget);
        expect(find.byTooltip('Remove Bo Kim'), findsOneWidget);

        handle.dispose();
      },
    );

    testWidgets(
      'a collaborator viewer sees Leave on their own row and NO affordance '
      "on a peer's row (top UX risk)",
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpScreen(tester, collaboratorA.uid);

        expect(find.text('You'), findsOneWidget);
        expect(find.text('Bo Kim'), findsOneWidget);
        // Own row: exactly one Leave affordance.
        expect(find.byIcon(Icons.logout), findsOneWidget);
        expect(find.byTooltip('Leave this sheet'), findsOneWidget);
        // Peer row: no remove, no leave — no trailing affordance at all.
        expect(find.byIcon(Icons.person_remove_outlined), findsNothing);
        expect(find.byTooltip('Remove Bo Kim'), findsNothing);

        handle.dispose();
      },
    );

    testWidgets('tapping Leave, then confirming, calls leavePiece', (
      tester,
    ) async {
      when(
        () => pieceRepository.leavePiece('p1'),
      ).thenAnswer((_) async => const Success<void>(null));
      await pumpScreen(tester, collaboratorA.uid);

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      verify(() => pieceRepository.leavePiece('p1')).called(1);
    });

    testWidgets('tapping remove, then confirming, calls removeCollaborator', (
      tester,
    ) async {
      when(
        () => pieceRepository.removeCollaborator('p1', 'b'),
      ).thenAnswer((_) async => const Success<void>(null));
      await pumpScreen(tester, ownerId);

      await tester.tap(find.byTooltip('Remove Bo Kim'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      verify(() => pieceRepository.removeCollaborator('p1', 'b')).called(1);
    });

    testWidgets('shows the owner row first, labelled Owner', (tester) async {
      await pumpScreen(tester, ownerId);

      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
    });

    testWidgets('shows an empty state for a piece with no collaborators', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CollaboratorsPage(
            pieceRepository: pieceRepository,
            pieceId: 'p1',
            currentUserId: ownerId,
          ),
        ),
      );
      controller.add([piece(const [])]);
      await tester.pump();
      await tester.pump();

      expect(find.text('No collaborators yet'), findsOneWidget);
      expect(
        find.text('Invite a friend to work on this sheet together.'),
        findsOneWidget,
      );
      // No `onInvite` given: no invite action anywhere on the empty state.
      expect(find.text('Invite a friend'), findsNothing);
    });

    testWidgets(
      'empty state with onInvite shows an Invite a friend action that '
      'invokes it',
      (tester) async {
        var invited = false;
        await tester.pumpWidget(
          MaterialApp(
            home: CollaboratorsPage(
              pieceRepository: pieceRepository,
              pieceId: 'p1',
              currentUserId: ownerId,
              onInvite: () => invited = true,
            ),
          ),
        );
        controller.add([piece(const [])]);
        await tester.pump();
        await tester.pump();
        // Flushes flutter_animate's initial delayed-start future for
        // `PrimaryButton`'s fade-in (see core_ui's `skeleton_test.dart` for
        // the same pattern); a zero-duration pump leaves it pending, which
        // trips the test binding's "no pending timers" invariant.
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.text('Invite a friend'), findsOneWidget);

        await tester.tap(find.text('Invite a friend'));
        await tester.pump();

        expect(invited, isTrue);
      },
    );

    testWidgets(
      'owner-viewer with onInvite sees an Invite a friend button below the '
      'roster, and tapping it invokes onInvite',
      (tester) async {
        var invited = false;
        await tester.pumpWidget(
          MaterialApp(
            home: CollaboratorsPage(
              pieceRepository: pieceRepository,
              pieceId: 'p1',
              currentUserId: ownerId,
              onInvite: () => invited = true,
            ),
          ),
        );
        controller.add([
          piece(const [collaboratorA, collaboratorB]),
        ]);
        await tester.pump();
        await tester.pump();
        // Flushes flutter_animate's initial delayed-start future for
        // `SecondaryButton`'s fade-in (see core_ui's `skeleton_test.dart` for
        // the same pattern); a zero-duration pump leaves it pending, which
        // trips the test binding's "no pending timers" invariant.
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.text('Invite a friend'), findsOneWidget);

        await tester.tap(find.text('Invite a friend'));
        await tester.pump();

        expect(invited, isTrue);
      },
    );

    testWidgets(
      'owner-viewer without onInvite sees no invite affordance',
      (tester) async {
        await pumpScreen(tester, ownerId);

        expect(find.text('Invite a friend'), findsNothing);
      },
    );

    testWidgets(
      'a collaborator-viewer never sees the invite affordance, even with '
      'onInvite set (owner-gated)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CollaboratorsPage(
              pieceRepository: pieceRepository,
              pieceId: 'p1',
              currentUserId: collaboratorA.uid,
              onInvite: () {},
            ),
          ),
        );
        controller.add([
          piece(const [collaboratorA, collaboratorB]),
        ]);
        await tester.pump();
        await tester.pump();

        expect(find.text('Invite a friend'), findsNothing);
      },
    );
  });
}
