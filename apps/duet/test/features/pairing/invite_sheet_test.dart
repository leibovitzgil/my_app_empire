import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:feature_paywall/feature_paywall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';
import 'package:remote_config/remote_config.dart';

class MockCollaboratorInviteService extends Mock
    implements CollaboratorInviteService {}

class MockInviteService extends Mock implements InviteService {}

class MockMonetizationService extends Mock implements MonetizationService {}

class MockPieceRepository extends Mock implements PieceRepository {}

void main() {
  group('showInviteSheet', () {
    const ownerId = 'owner-1';
    const pieceId = 'p1';
    const email = 'collaborator@example.com';
    const recipient = InviteRecipient(uid: 'collaborator-1', email: email);

    late MockCollaboratorInviteService collaboratorInviteService;
    late MockInviteService inviteService;
    late MockMonetizationService monetization;
    late MockPieceRepository pieceRepository;

    Piece piece({List<Collaborator> collaborators = const []}) => Piece(
      id: pieceId,
      title: 'Nocturne',
      basePdfChecksum: 'c',
      basePdfPath: '/tmp/p.pdf',
      ownerId: ownerId,
      collaborators: collaborators,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    setUp(() {
      collaboratorInviteService = MockCollaboratorInviteService();
      inviteService = MockInviteService();
      monetization = MockMonetizationService();
      pieceRepository = MockPieceRepository();
      // The invite sheet's own `PaywallBloc` also loads offerings on start,
      // independent of the invite gate check.
      when(() => monetization.getOfferings()).thenAnswer((_) async => null);
    });

    Future<void> openSheet(
      WidgetTester tester, {
      RemoteConfigService? remoteConfig,
    }) async {
      // The same seam the app composes in `showInviteSheetFor`: the
      // `invite_links_enabled` kill-switch is read off the (fake)
      // remote-config contract and threaded in as a parameter.
      final config = remoteConfig ?? InMemoryRemoteConfigService();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showInviteSheet(
                  context,
                  collaboratorInviteService: collaboratorInviteService,
                  inviteService: inviteService,
                  monetizationService: monetization,
                  pieceRepository: pieceRepository,
                  ownerId: ownerId,
                  pieceId: pieceId,
                  linkSharingEnabled: config.inviteLinksEnabled,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
    }

    testWidgets(
      'a free-tier owner at the collaborator cap sees the paywall instead '
      'of the invite affordances',
      (tester) async {
        when(() => monetization.isProUser()).thenAnswer((_) async => false);
        when(() => pieceRepository.getPiece(pieceId)).thenAnswer(
          (_) async => Success(
            piece(collaborators: const [Collaborator(uid: 'already-paired')]),
          ),
        );

        await openSheet(tester);
        await tester.pumpAndSettle();

        expect(find.byType(PaywallScreen), findsOneWidget);
        expect(find.text('Send invite'), findsNothing);
      },
    );

    testWidgets(
      'a pro owner never sees the paywall and can send an email invite',
      (tester) async {
        when(() => monetization.isProUser()).thenAnswer((_) async => true);
        when(
          () => pieceRepository.getPiece(pieceId),
        ).thenAnswer((_) async => Success(piece()));
        when(
          () => collaboratorInviteService.lookupInvitee(
            pieceId: pieceId,
            email: email,
          ),
        ).thenAnswer((_) async => const Success(Resolved(recipient)));
        when(
          () => collaboratorInviteService.sendInvite(
            pieceId: pieceId,
            ownerId: ownerId,
            email: email,
            ownerName: any(named: 'ownerName'),
          ),
        ).thenAnswer((_) async => const Success(Resolved(recipient)));

        await openSheet(tester);
        await tester.pumpAndSettle();

        expect(find.byType(PaywallScreen), findsNothing);
        expect(find.text('Share invite link instead'), findsOneWidget);

        await tester.enterText(find.byType(TextField), email);
        await tester.pumpAndSettle();

        expect(find.byType(PersonTile), findsOneWidget);

        await tester.tap(find.text('Send invite'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Invite sent'), findsWidgets);
      },
    );

    testWidgets(
      'no discoverable account falls back to sharing an invite link',
      (tester) async {
        when(() => monetization.isProUser()).thenAnswer((_) async => true);
        when(
          () => pieceRepository.getPiece(pieceId),
        ).thenAnswer((_) async => Success(piece()));
        when(
          () => collaboratorInviteService.lookupInvitee(
            pieceId: pieceId,
            email: email,
          ),
        ).thenAnswer((_) async => const Success(NoAccount()));
        when(
          () => inviteService.createInvite(
            ownerId: ownerId,
            pieceId: pieceId,
            ownerName: any(named: 'ownerName'),
          ),
        ).thenAnswer(
          (_) async => Success(
            InviteLink(
              token: 'tok',
              uri: Uri.parse('https://duet.app/invite/tok'),
              pieceId: pieceId,
              ownerId: ownerId,
            ),
          ),
        );

        await openSheet(tester);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), email);
        await tester.pumpAndSettle();

        expect(find.textContaining('No Duet account found'), findsOneWidget);

        await tester.tap(find.text('Share invite link instead'));
        await tester.pumpAndSettle();

        expect(find.text('https://duet.app/invite/tok'), findsOneWidget);
      },
    );

    testWidgets(
      'a free-tier owner under the cap is not gated',
      (tester) async {
        when(() => monetization.isProUser()).thenAnswer((_) async => false);
        when(
          () => pieceRepository.getPiece(pieceId),
        ).thenAnswer((_) async => Success(piece()));

        await openSheet(tester);
        await tester.pumpAndSettle();

        expect(find.byType(PaywallScreen), findsNothing);
        expect(find.text('Share invite link instead'), findsOneWidget);
      },
    );

    group('invite_links_enabled kill-switch (M6.4)', () {
      setUp(() {
        when(() => monetization.isProUser()).thenAnswer((_) async => true);
        when(
          () => pieceRepository.getPiece(pieceId),
        ).thenAnswer((_) async => Success(piece()));
      });

      testWidgets(
        'flag off hides the link-share affordance; email invites remain',
        (tester) async {
          await openSheet(
            tester,
            remoteConfig: InMemoryRemoteConfigService(
              overrides: const {RemoteConfigKeys.inviteLinksEnabled: false},
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Share invite link instead'), findsNothing);
          expect(find.text('or'), findsNothing);
          // The primary email path is untouched by the kill-switch.
          expect(find.text('Send invite'), findsOneWidget);
        },
      );

      testWidgets(
        'the committed default (flag on) keeps the link-share affordance',
        (tester) async {
          await openSheet(
            tester,
            remoteConfig: InMemoryRemoteConfigService(),
          );
          await tester.pumpAndSettle();

          expect(find.text('Share invite link instead'), findsOneWidget);
        },
      );
    });
  });
}
