import 'package:core_utils/core_utils.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';
import 'package:pieces/pieces.dart';

class MockInviteService extends Mock implements InviteService {}

class MockPieceRepository extends Mock implements PieceRepository {}

class MockMonetizationService extends Mock implements MonetizationService {}

void main() {
  group('AcceptInviteScreen', () {
    const token = 'tok-1';
    const collaboratorId = 'collaborator-1';
    const details = InviteDetails(
      pieceId: 'p1',
      pieceTitle: 'Clair de Lune',
      ownerId: 'owner-1',
    );

    late MockInviteService inviteService;
    late MockPieceRepository pieceRepository;
    late MockMonetizationService monetization;

    Piece piece({List<Collaborator> collaborators = const []}) => Piece(
      id: 'p1',
      title: 'Clair de Lune',
      basePdfChecksum: 'c',
      basePdfPath: '/tmp/p.pdf',
      ownerId: 'owner-1',
      collaborators: collaborators,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    setUp(() {
      inviteService = MockInviteService();
      pieceRepository = MockPieceRepository();
      monetization = MockMonetizationService();
      when(
        () => pieceRepository.getPiece('p1'),
      ).thenAnswer((_) async => Success(piece()));
      when(() => monetization.isProUser()).thenAnswer((_) async => false);
    });

    Widget buildPage({void Function(String pieceId)? onAccepted}) {
      return MaterialApp(
        home: AcceptInvitePage(
          inviteService: inviteService,
          pieceRepository: pieceRepository,
          monetizationService: monetization,
          token: token,
          collaboratorId: collaboratorId,
          onAccepted: onAccepted ?? (_) {},
        ),
      );
    }

    testWidgets('shows the piece title and owner once resolved', (
      tester,
    ) async {
      when(
        () => inviteService.resolveInvite(token),
      ).thenAnswer((_) async => const Success(details));

      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump();
      // Flushes flutter_animate's initial delayed-start future for
      // `PrimaryButton`/`SecondaryButton`'s fade-in (see core_ui's
      // `skeleton_test.dart` for the same pattern); a zero-duration pump
      // leaves it pending, tripping the test binding's teardown invariant.
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('Clair de Lune'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      // `details` above carries no `ownerName`, so the screen must fall
      // back to the fixed "Owner" placeholder rather than showing
      // nothing/crashing.
      expect(find.text('Owner'), findsOneWidget);
    });

    testWidgets(
      'shows the real ownerName when the invite carries one, rather '
      'than the "Owner" fallback',
      (tester) async {
        when(() => inviteService.resolveInvite(token)).thenAnswer(
          (_) async => const Success(
            InviteDetails(
              pieceId: 'p1',
              pieceTitle: 'Clair de Lune',
              ownerId: 'owner-1',
              ownerName: 'Jane Doe',
            ),
          ),
        );

        await tester.pumpWidget(buildPage());
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.text('Jane Doe'), findsOneWidget);
        expect(find.text('Owner'), findsNothing);
      },
    );

    testWidgets('shows an error state for an invalid token', (tester) async {
      when(() => inviteService.resolveInvite(token)).thenAnswer(
        (_) async => const ResultFailure<InviteDetails>(
          InviteException('This invite link is invalid or has expired.'),
        ),
      );

      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text("Couldn't open this invite"), findsOneWidget);
      // Shown twice: once in `ErrorRetryView`'s message, once in the
      // snackbar the `BlocConsumer` listener surfaces for the same failure.
      expect(find.textContaining('invalid or has expired'), findsWidgets);
    });

    testWidgets('accepting calls onAccepted with the paired piece id', (
      tester,
    ) async {
      when(
        () => inviteService.resolveInvite(token),
      ).thenAnswer((_) async => const Success(details));
      when(
        () => inviteService.acceptInvite(
          token,
          collaboratorId: collaboratorId,
          collaboratorName: any(named: 'collaboratorName'),
          collaboratorEmail: any(named: 'collaboratorEmail'),
        ),
      ).thenAnswer((_) async => const Success<void>(null));

      String? acceptedPieceId;
      await tester.pumpWidget(
        buildPage(onAccepted: (pieceId) => acceptedPieceId = pieceId),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Accept'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(acceptedPieceId, 'p1');
    });

    testWidgets(
      'shows an already-collaborator body when the accepter already has '
      'access, with a Continue that invokes onAccepted',
      (tester) async {
        when(
          () => inviteService.resolveInvite(token),
        ).thenAnswer((_) async => const Success(details));
        when(() => pieceRepository.getPiece('p1')).thenAnswer(
          (_) async => Success(
            piece(collaborators: const [Collaborator(uid: collaboratorId)]),
          ),
        );

        String? acceptedPieceId;
        await tester.pumpWidget(
          buildPage(onAccepted: (pieceId) => acceptedPieceId = pieceId),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.textContaining('already a collaborator'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);

        await tester.tap(find.text('Continue'));
        await tester.pump();

        expect(acceptedPieceId, 'p1');
      },
    );

    testWidgets(
      'shows an at-cap body when the piece is already at its collaborator '
      'cap',
      (tester) async {
        when(
          () => inviteService.resolveInvite(token),
        ).thenAnswer((_) async => const Success(details));
        when(() => pieceRepository.getPiece('p1')).thenAnswer(
          (_) async => Success(
            piece(collaborators: const [Collaborator(uid: 'someone-else')]),
          ),
        );

        await tester.pumpWidget(buildPage());
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.textContaining('Free plan allows 1'), findsOneWidget);
        expect(find.text('Got it'), findsOneWidget);
        expect(find.text('Accept'), findsNothing);
      },
    );
  });
}
