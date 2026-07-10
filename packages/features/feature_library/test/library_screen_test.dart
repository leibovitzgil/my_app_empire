import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:feature_library/feature_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
            appName: 'Duet',
            onOpenScore: onOpenScore ?? (_) {},
            onOpenSettings: onOpenSettings,
            onInvitePiece: onInvitePiece,
            onOpenCollaborators: onOpenCollaborators,
          ),
        ),
      );
      await tester.pump();
      // Flushes flutter_animate's initial delayed-start future for the
      // loading state's skeleton grid shimmer (see core_ui's
      // `skeleton_test.dart`); a zero-duration pump leaves it pending, which
      // trips the test binding's "no pending timers" invariant at teardown.
      await tester.pump(const Duration(milliseconds: 1));
    }

    testWidgets(
      'with no sheets at all shows the empty-library state and an Import '
      'a sheet action',
      (tester) async {
        await pumpScreen(tester);
        piecesController.add(const []);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Your library is empty'), findsOneWidget);
        expect(find.text('Import a sheet'), findsOneWidget);
      },
    );

    testWidgets('the Import FAB is present once content has loaded', (
      tester,
    ) async {
      await pumpScreen(tester);
      piecesController.add([myPiece(), sharedPiece()]);
      await tester.pump();
      await tester.pump();

      expect(find.byTooltip('Import a sheet'), findsOneWidget);
    });

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
      'tapping the My sheets chip shows owned sheets, not shared ones',
      (tester) async {
        await pumpScreen(tester);
        piecesController.add([myPiece(), sharedPiece()]);
        await tester.pump();
        await tester.pump();

        await tester.tap(find.widgetWithText(ChoiceChip, 'My sheets'));
        await tester.pumpAndSettle();

        expect(find.text('Clair de Lune'), findsWidgets);
        expect(find.text('Nocturne'), findsNothing);
      },
    );

    testWidgets(
      'tapping the Shared with me chip shows shared sheets (with the owner '
      "in the card's caption), not owned ones",
      (tester) async {
        await pumpScreen(tester);
        piecesController.add([myPiece(), sharedPiece(ownerName: 'Jane Doe')]);
        await tester.pump();
        await tester.pump();

        await tester.tap(find.widgetWithText(ChoiceChip, 'Shared with me'));
        await tester.pumpAndSettle();

        expect(find.text('Nocturne'), findsWidgets);
        expect(find.text('from Jane Doe'), findsOneWidget);
        expect(find.text('Clair de Lune'), findsNothing);
      },
    );

    testWidgets(
      'shows "Nothing shared yet" on the Shared with me chip when nothing '
      'is shared',
      (tester) async {
        await pumpScreen(tester);
        piecesController.add([myPiece()]);
        await tester.pump();
        await tester.pump();

        await tester.tap(find.widgetWithText(ChoiceChip, 'Shared with me'));
        await tester.pumpAndSettle();

        expect(find.text('Nothing shared yet'), findsOneWidget);
      },
    );

    testWidgets('tapping a cover card opens the score for that piece', (
      tester,
    ) async {
      Piece? opened;
      await pumpScreen(tester, onOpenScore: (p) => opened = p);
      piecesController.add([myPiece()]);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Clair de Lune').first);
      await tester.pump();

      expect(opened?.id, 'p1');
    });

    testWidgets(
      'long-pressing a cover card opens quick actions, and Details opens '
      'Piece Detail instead of the score',
      (tester) async {
        when(
          () => repository.getPiece('p1'),
        ).thenAnswer((_) async => Success(myPiece()));
        Piece? opened;
        await pumpScreen(tester, onOpenScore: (p) => opened = p);
        piecesController.add([myPiece()]);
        await tester.pump();
        await tester.pump();

        await tester.longPress(find.text('Clair de Lune').first);
        await tester.pumpAndSettle();

        expect(find.text('Details'), findsOneWidget);
        await tester.tap(find.text('Details'));
        await tester.pumpAndSettle();

        expect(find.byType(PieceDetailScreen), findsOneWidget);
        // The card's own onOpenScore never fired for the Details tap.
        expect(opened, isNull);
      },
    );

    testWidgets(
      'quick actions on an owned sheet offer Invite a partner, which fires '
      'the callback',
      (tester) async {
        Piece? invited;
        await pumpScreen(tester, onInvitePiece: (p) => invited = p);
        piecesController.add([myPiece()]);
        await tester.pump();
        await tester.pump();

        await tester.longPress(find.text('Clair de Lune').first);
        await tester.pumpAndSettle();

        expect(find.text('Invite a partner'), findsOneWidget);
        await tester.tap(find.text('Invite a partner'));
        await tester.pumpAndSettle();

        expect(invited?.id, 'p1');
      },
    );

    testWidgets(
      'quick actions on a shared sheet are owner-gated: no Invite a partner, '
      'but a Leave action',
      (tester) async {
        await pumpScreen(tester, onInvitePiece: (_) {});
        piecesController.add([sharedPiece()]);
        await tester.pump();
        await tester.pump();

        await tester.longPress(find.text('Nocturne').first);
        await tester.pumpAndSettle();

        expect(find.text('Invite a partner'), findsNothing);
        expect(find.text('Leave sheet'), findsOneWidget);
      },
    );

    testWidgets(
      'quick actions on an owned sheet: Delete, after confirming, calls '
      'deletePiece',
      (tester) async {
        when(
          () => repository.deletePiece('p1'),
        ).thenAnswer((_) async => const Success<void>(null));
        await pumpScreen(tester);
        piecesController.add([myPiece()]);
        await tester.pump();
        await tester.pump();

        await tester.longPress(find.text('Clair de Lune').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Delete this sheet?'), findsOneWidget);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        verify(() => repository.deletePiece('p1')).called(1);
        // Flush the success snackbar's auto-dismiss timer so teardown sees
        // no pending timers.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'quick actions on a shared sheet: Leave, after confirming, calls '
      'leavePiece',
      (tester) async {
        when(
          () => repository.leavePiece('p2'),
        ).thenAnswer((_) async => const Success<void>(null));
        await pumpScreen(tester);
        piecesController.add([sharedPiece()]);
        await tester.pump();
        await tester.pump();

        await tester.longPress(find.text('Nocturne').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Leave sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Leave this sheet?'), findsOneWidget);
        await tester.tap(find.text('Leave'));
        await tester.pumpAndSettle();

        verify(() => repository.leavePiece('p2')).called(1);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'tapping the Favorites chip shows the coming-soon placeholder',
      (tester) async {
        await pumpScreen(tester);
        piecesController.add([myPiece()]);
        await tester.pump();
        await tester.pump();

        // Favorites is the last chip in a horizontally-scrollable row, so
        // bring it into view before tapping (the narrow test surface scrolls
        // it off the right edge).
        final favoritesChip = find.widgetWithText(ChoiceChip, 'Favorites');
        await tester.ensureVisible(favoritesChip);
        await tester.pumpAndSettle();
        await tester.tap(favoritesChip);
        await tester.pumpAndSettle();

        expect(find.text('Favorites coming soon'), findsOneWidget);
        expect(find.text('Clair de Lune'), findsNothing);
      },
    );

    testWidgets(
      'typing in the search field filters by title and shows a no-matches '
      'message when nothing matches',
      (tester) async {
        await pumpScreen(tester);
        piecesController.add([
          myPiece(),
          myPiece(id: 'p3', title: 'Nocturne'),
        ]);
        await tester.pump();
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'clair');
        await tester.pumpAndSettle();

        // The non-matching sheet is filtered out; no empty message yet.
        expect(find.text('Nocturne'), findsNothing);
        expect(find.textContaining('No matches for'), findsNothing);

        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();

        expect(find.textContaining('No matches for'), findsOneWidget);
      },
    );

    testWidgets(
      'search is global: finds a shared sheet even while the My sheets '
      'filter is active',
      (tester) async {
        await pumpScreen(tester);
        piecesController.add([myPiece(), sharedPiece()]);
        await tester.pump();
        await tester.pump();

        await tester.tap(find.widgetWithText(ChoiceChip, 'My sheets'));
        await tester.pumpAndSettle();
        // The shared sheet is filtered out of the shelf...
        expect(find.text('Nocturne'), findsNothing);

        await tester.enterText(find.byType(TextField), 'nocturne');
        await tester.pumpAndSettle();

        // ...but a global search still surfaces it.
        expect(find.textContaining('No matches for'), findsNothing);
        expect(find.textContaining('Shared by'), findsOneWidget);
      },
    );

    testWidgets(
      'cover cards expose tap and long-press as semantic actions, so '
      'assistive tech can open and quick-action them',
      (tester) async {
        await pumpScreen(tester);
        piecesController.add([myPiece()]);
        await tester.pump();
        await tester.pump();

        final handle = tester.ensureSemantics();
        final data = tester
            .getSemantics(find.bySemanticsLabel(RegExp('Clair de Lune')))
            .getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.hasAction(SemanticsAction.longPress), isTrue);
        handle.dispose();
      },
    );
  });

  group('columnsForWidth', () {
    test('steps 2 → 3 → 4 → 5 at the documented breakpoints', () {
      expect(columnsForWidth(320), 2);
      expect(columnsForWidth(599), 2);
      expect(columnsForWidth(600), 3);
      expect(columnsForWidth(899), 3);
      expect(columnsForWidth(900), 4);
      expect(columnsForWidth(1023), 4);
      expect(columnsForWidth(1024), 5);
      expect(columnsForWidth(1600), 5);
    });
  });
}
