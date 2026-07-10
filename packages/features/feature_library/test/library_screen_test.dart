import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:feature_library/feature_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';

class MockPieceRepository extends Mock implements PieceRepository {}

class MockPdfRenderService extends Mock implements PdfRenderService {}

void main() {
  group('LibraryHomeScreen', () {
    const currentUserId = 'me';
    const otherOwnerId = 'owner-2';

    late MockPieceRepository repository;
    late MockPdfRenderService renderService;
    late StreamController<List<Piece>> piecesController;

    Piece myPiece({
      String id = 'p1',
      String title = 'Clair de Lune',
      List<Collaborator> collaborators = const [],
      DateTime? updatedAt,
    }) => Piece(
      id: id,
      title: title,
      basePdfChecksum: 'checksum',
      basePdfPath: '/tmp/$id.pdf',
      ownerId: currentUserId,
      collaborators: collaborators,
      createdAt: DateTime(2024),
      updatedAt: updatedAt ?? DateTime(2024),
    );

    Piece sharedPiece({
      String id = 'p2',
      String title = 'Nocturne',
      String? ownerName,
      DateTime? updatedAt,
    }) => Piece(
      id: id,
      title: title,
      basePdfChecksum: 'checksum',
      basePdfPath: '/tmp/$id.pdf',
      ownerId: otherOwnerId,
      ownerName: ownerName,
      collaborators: const [Collaborator(uid: currentUserId)],
      createdAt: DateTime(2024),
      updatedAt: updatedAt ?? DateTime(2024),
    );

    setUp(() {
      repository = MockPieceRepository();
      renderService = MockPdfRenderService();
      piecesController = StreamController<List<Piece>>.broadcast();
      when(
        () => repository.watchPieces(),
      ).thenAnswer((_) => piecesController.stream);
    });

    tearDown(() async => piecesController.close());

    Future<void> pumpScreen(
      WidgetTester tester, {
      VoidCallback? onOpenSettings,
      void Function(Piece piece)? onOpenScore,
      void Function(Piece piece)? onInvitePiece,
      void Function(Piece piece)? onOpenCollaborators,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LibraryPage(
            pieceRepository: repository,
            renderService: renderService,
            currentUserId: currentUserId,
            onOpenScore: onOpenScore ?? (_) {},
            onOpenSettings: onOpenSettings,
            onInvitePiece: onInvitePiece,
            onOpenCollaborators: onOpenCollaborators,
          ),
        ),
      );
      await tester.pump();
      // Flushes flutter_animate's initial delayed-start future for the
      // loading state's `SkeletonList` shimmer (see core_ui's
      // `skeleton_test.dart`); a zero-duration pump leaves it pending, which
      // trips the test binding's "no pending timers" invariant at teardown.
      await tester.pump(const Duration(milliseconds: 1));
    }

    testWidgets(
      'with no sheets at all shows the My sheets empty state and an '
      'Import a sheet action',
      (tester) async {
        await pumpScreen(tester);
        piecesController.add(const []);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Your library is empty'), findsOneWidget);
        expect(find.text('Import a sheet'), findsOneWidget);
      },
    );

    testWidgets(
      'the import action is always present in the app bar, regardless of '
      'tab or content',
      (tester) async {
        await pumpScreen(tester);
        piecesController.add([myPiece(), sharedPiece()]);
        await tester.pump();
        await tester.pump();

        expect(find.byTooltip('Import a sheet'), findsOneWidget);

        await tester.tap(find.text('Shared with me'));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Import a sheet'), findsOneWidget);
      },
    );

    testWidgets('hides the settings action when onOpenSettings is null', (
      tester,
    ) async {
      await pumpScreen(tester);
      piecesController.add(const []);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byTooltip('Settings'), findsNothing);
    });

    testWidgets(
      'shows the settings action and invokes the callback when given',
      (tester) async {
        var opened = 0;
        await pumpScreen(tester, onOpenSettings: () => opened++);
        piecesController.add(const []);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byTooltip('Settings'), findsOneWidget);
        await tester.tap(find.byTooltip('Settings'));
        await tester.pump();

        expect(opened, 1);
      },
    );

    testWidgets(
      'owned sheets show under My sheets, not under Shared with me',
      (tester) async {
        await pumpScreen(tester);
        piecesController.add([myPiece(), sharedPiece()]);
        await tester.pump();
        await tester.pump();

        // "My sheets" is the default (first) tab.
        expect(find.text('Clair de Lune'), findsOneWidget);
        expect(find.text('Nocturne'), findsNothing);
      },
    );

    testWidgets(
      'shared sheets show under Shared with me, with the owner in the '
      'subtitle, not under My sheets',
      (tester) async {
        await pumpScreen(tester);
        piecesController.add([
          myPiece(),
          sharedPiece(ownerName: 'Jane Doe'),
        ]);
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Shared with me'));
        await tester.pumpAndSettle();

        expect(find.text('Nocturne'), findsOneWidget);
        expect(find.textContaining('Shared by Jane Doe'), findsOneWidget);
        expect(find.text('Clair de Lune'), findsNothing);
      },
    );

    testWidgets(
      'shows "Nothing shared yet" on the Shared with me tab when nothing '
      'is shared',
      (tester) async {
        await pumpScreen(tester);
        piecesController.add([myPiece()]);
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Shared with me'));
        await tester.pumpAndSettle();

        expect(find.text('Nothing shared yet'), findsOneWidget);
      },
    );

    testWidgets('tapping a row opens the score for that piece', (
      tester,
    ) async {
      Piece? opened;
      await pumpScreen(tester, onOpenScore: (p) => opened = p);
      piecesController.add([myPiece()]);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Clair de Lune'));
      await tester.pump();

      expect(opened?.id, 'p1');
    });

    testWidgets(
      'tapping the trailing info button opens Piece Detail instead of the '
      'score',
      (tester) async {
        when(
          () => repository.getPiece('p1'),
        ).thenAnswer((_) async => Success(myPiece()));
        Piece? opened;
        await pumpScreen(tester, onOpenScore: (p) => opened = p);
        piecesController.add([myPiece()]);
        await tester.pump();
        await tester.pump();

        expect(find.byTooltip('Clair de Lune details'), findsOneWidget);

        await tester.tap(find.byTooltip('Clair de Lune details'));
        await tester.pumpAndSettle();

        expect(find.byType(PieceDetailScreen), findsOneWidget);
        // The row tap's own onOpenScore never fired for the info tap.
        expect(opened, isNull);
      },
    );
  });
}
