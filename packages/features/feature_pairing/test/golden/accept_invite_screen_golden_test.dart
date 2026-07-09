@Tags(['golden'])
library;

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
  group('AcceptInviteScreen goldens', () {
    const token = 'tok-1';
    const collaboratorId = 'collaborator-1';
    const details = InviteDetails(
      pieceId: 'p1',
      pieceTitle: 'Clair de Lune',
      ownerId: 'owner-1',
      ownerName: 'Jane Doe',
    );

    late MockInviteService inviteService;
    late MockPieceRepository pieceRepository;
    late MockMonetizationService monetization;

    Piece piece(List<Collaborator> collaborators) => Piece(
      id: 'p1',
      title: 'Clair de Lune',
      basePdfChecksum: 'c',
      basePdfPath: '/tmp/p.pdf',
      ownerId: 'owner-1',
      ownerName: 'Jane Doe',
      collaborators: collaborators,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    setUp(() {
      inviteService = MockInviteService();
      pieceRepository = MockPieceRepository();
      monetization = MockMonetizationService();
      when(
        () => inviteService.resolveInvite(token),
      ).thenAnswer((_) async => const Success(details));
    });

    Future<void> pumpScreen(WidgetTester tester, Brightness brightness) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, brightness: brightness),
          home: AcceptInvitePage(
            inviteService: inviteService,
            pieceRepository: pieceRepository,
            monetizationService: monetization,
            token: token,
            collaboratorId: collaboratorId,
            onAccepted: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('already-collaborator body (light)', (tester) async {
      when(() => pieceRepository.getPiece('p1')).thenAnswer(
        (_) async => Success(
          piece(const [Collaborator(uid: collaboratorId)]),
        ),
      );

      await pumpScreen(tester, Brightness.light);

      await expectLater(
        find.byType(AcceptInviteScreen),
        matchesGoldenFile('goldens/accept_invite_already_collaborator.png'),
      );
    });

    testWidgets('at-cap body (dark)', (tester) async {
      when(() => pieceRepository.getPiece('p1')).thenAnswer(
        (_) async => Success(
          piece(const [Collaborator(uid: 'someone-else')]),
        ),
      );
      when(() => monetization.isProUser()).thenAnswer((_) async => false);

      await pumpScreen(tester, Brightness.dark);

      await expectLater(
        find.byType(AcceptInviteScreen),
        matchesGoldenFile('goldens/accept_invite_at_cap.png'),
      );
    });
  });
}
