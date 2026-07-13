import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/library/library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPieceRepository extends Mock implements PieceRepository {}

void main() {
  group('PieceDetailScreen', () {
    const ownerId = 'owner-1';
    const collaboratorId = 'collaborator-1';

    late MockPieceRepository repository;

    setUp(() {
      repository = MockPieceRepository();
    });

    Piece piece({
      List<Collaborator> collaborators = const [
        Collaborator(uid: collaboratorId),
      ],
      String? ownerName,
    }) => Piece(
      id: 'p1',
      title: 'Clair de Lune',
      basePdfChecksum: 'checksum',
      basePdfPath: '/tmp/p1.pdf',
      ownerId: ownerId,
      ownerName: ownerName,
      collaborators: collaborators,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    Future<void> pumpScreen(
      WidgetTester tester, {
      required Piece piece,
      required String currentUserId,
      void Function(Piece piece)? onOpenCollaborators,
      void Function(Piece piece)? onInvitePiece,
      void Function(Piece piece)? onExportBundle,
      VoidCallback? onImportBundle,
    }) async {
      when(
        () => repository.getPiece(piece.id),
      ).thenAnswer((_) async => Success(piece));
      await tester.pumpWidget(
        MaterialApp(
          home: PieceDetailPage(
            pieceRepository: repository,
            currentUserId: currentUserId,
            pieceId: piece.id,
            onOpenScore: (_) {},
            onOpenCollaborators: onOpenCollaborators,
            onInvitePiece: onInvitePiece,
            onExportBundle: onExportBundle,
            onImportBundle: onImportBundle,
          ),
        ),
      );
      await tester.pump();
      // Flushes flutter_animate's initial delayed-start future for the
      // "Open score" PrimaryButton's fade-in (see core_ui's
      // `skeleton_test.dart`); a zero-duration pump leaves it pending, which
      // trips the test binding's "no pending timers" invariant at teardown.
      await tester.pump(const Duration(milliseconds: 1));
    }

    testWidgets(
      'a collaborator sees the real ownerName and "Shared this sheet with '
      'you"',
      (tester) async {
        await pumpScreen(
          tester,
          piece: piece(ownerName: 'Jane Doe'),
          currentUserId: collaboratorId,
        );

        expect(find.text('Jane Doe'), findsOneWidget);
        expect(find.text('Shared this sheet with you'), findsOneWidget);
        expect(find.text('Owner'), findsNothing);
      },
    );

    testWidgets(
      'a collaborator sees the "Owner" fallback when the piece has no '
      'ownerName yet',
      (tester) async {
        await pumpScreen(tester, piece: piece(), currentUserId: collaboratorId);

        expect(find.text('Owner'), findsOneWidget);
      },
    );

    testWidgets(
      'the owner never sees the "shared with you" owner tile, even with no '
      'collaborators',
      (tester) async {
        await pumpScreen(
          tester,
          piece: piece(collaborators: const []),
          currentUserId: ownerId,
        );

        expect(find.text('Shared this sheet with you'), findsNothing);
      },
    );

    testWidgets(
      'hides the Collaborators tile when onOpenCollaborators is null',
      (tester) async {
        await pumpScreen(tester, piece: piece(), currentUserId: ownerId);

        expect(find.textContaining('Collaborators ('), findsNothing);
      },
    );

    testWidgets(
      'shows "Collaborators (N)" and navigates on tap when wired',
      (tester) async {
        Piece? tapped;
        await pumpScreen(
          tester,
          piece: piece(
            collaborators: const [
              Collaborator(uid: collaboratorId),
              Collaborator(uid: 'collaborator-2'),
            ],
          ),
          currentUserId: ownerId,
          onOpenCollaborators: (p) => tapped = p,
        );

        expect(find.text('Collaborators (2)'), findsOneWidget);

        await tester.tap(find.text('Collaborators (2)'));
        await tester.pump();

        expect(tapped?.id, 'p1');
      },
    );

    testWidgets(
      'the owner sees an Invite a friend button when onInvitePiece is '
      'given, and tapping it invokes it',
      (tester) async {
        Piece? invited;
        await pumpScreen(
          tester,
          piece: piece(),
          currentUserId: ownerId,
          onInvitePiece: (p) => invited = p,
        );

        expect(find.text('Invite a friend'), findsOneWidget);

        await tester.tap(find.text('Invite a friend'));
        await tester.pump();

        expect(invited?.id, 'p1');
      },
    );

    testWidgets(
      'the owner sees no Invite a friend button when onInvitePiece is null',
      (tester) async {
        await pumpScreen(tester, piece: piece(), currentUserId: ownerId);

        expect(find.text('Invite a friend'), findsNothing);
      },
    );

    testWidgets(
      'a collaborator never sees the Invite a friend button, even with '
      'onInvitePiece set (owner-gated)',
      (tester) async {
        await pumpScreen(
          tester,
          piece: piece(),
          currentUserId: collaboratorId,
          onInvitePiece: (_) {},
        );

        expect(find.text('Invite a friend'), findsNothing);
      },
    );

    testWidgets(
      'Offline sharing: shows the section and Export invokes onExportBundle',
      (tester) async {
        Piece? exported;
        await pumpScreen(
          tester,
          piece: piece(),
          currentUserId: ownerId,
          onExportBundle: (p) => exported = p,
          onImportBundle: () {},
        );

        expect(find.text('Offline sharing'), findsOneWidget);
        expect(find.text('Import review bundle'), findsOneWidget);

        await tester.tap(find.text('Export review bundle'));
        await tester.pump();

        expect(exported?.id, 'p1');
      },
    );

    testWidgets(
      'Offline sharing: the section hides when neither callback is wired',
      (tester) async {
        await pumpScreen(tester, piece: piece(), currentUserId: ownerId);

        expect(find.text('Offline sharing'), findsNothing);
        expect(find.text('Export review bundle'), findsNothing);
      },
    );

    testWidgets('the owner overflow shows Rename and Delete, never Leave', (
      tester,
    ) async {
      await pumpScreen(tester, piece: piece(), currentUserId: ownerId);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Leave'), findsNothing);
    });

    testWidgets('a collaborator overflow shows only Leave', (tester) async {
      await pumpScreen(tester, piece: piece(), currentUserId: collaboratorId);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Rename'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets(
      'the owner: Rename via the overflow menu prompts "Rename sheet" and '
      'submits the new title',
      (tester) async {
        when(
          () => repository.renamePiece('p1', 'New title'),
        ).thenAnswer((_) async => const Success<void>(null));
        await pumpScreen(tester, piece: piece(), currentUserId: ownerId);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rename'));
        await tester.pumpAndSettle();

        expect(find.text('Rename sheet'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'New title');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        verify(() => repository.renamePiece('p1', 'New title')).called(1);
      },
    );

    testWidgets(
      'the owner: Delete via the overflow menu, after confirming "Delete '
      'this sheet?", calls deletePiece',
      (tester) async {
        when(
          () => repository.deletePiece('p1'),
        ).thenAnswer((_) async => const Success<void>(null));
        await pumpScreen(tester, piece: piece(), currentUserId: ownerId);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Delete this sheet?'), findsOneWidget);
        expect(
          find.text(
            'This permanently deletes the sheet for everyone on it.',
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();

        verify(() => repository.deletePiece('p1')).called(1);
      },
    );

    testWidgets(
      'a collaborator: Leave via the overflow menu, after confirming '
      '"Leave this sheet?", calls leavePiece',
      (tester) async {
        when(
          () => repository.leavePiece('p1'),
        ).thenAnswer((_) async => const Success<void>(null));
        await pumpScreen(
          tester,
          piece: piece(),
          currentUserId: collaboratorId,
        );

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Leave'));
        await tester.pumpAndSettle();

        expect(find.text('Leave this sheet?'), findsOneWidget);

        await tester.tap(find.text('Leave').last);
        await tester.pumpAndSettle();

        verify(() => repository.leavePiece('p1')).called(1);
      },
    );

    testWidgets('shows a failure state with the sheet-worded copy', (
      tester,
    ) async {
      when(() => repository.getPiece('missing')).thenAnswer(
        (_) async => ResultFailure(StateError('Unknown piece: missing')),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PieceDetailPage(
            pieceRepository: repository,
            currentUserId: ownerId,
            pieceId: 'missing',
            onOpenScore: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load this sheet"), findsOneWidget);
    });
  });
}
