import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';
import 'package:pieces/pieces.dart';

class MockCollaboratorInviteService extends Mock
    implements CollaboratorInviteService {}

class MockInviteService extends Mock implements InviteService {}

class MockMonetizationService extends Mock implements MonetizationService {}

class MockPieceRepository extends Mock implements PieceRepository {}

void main() {
  group('InviteBloc', () {
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
    });

    InviteBloc buildBloc() => InviteBloc(
      collaboratorInviteService: collaboratorInviteService,
      inviteService: inviteService,
      monetizationService: monetization,
      pieceRepository: pieceRepository,
      ownerId: ownerId,
      pieceId: pieceId,
    );

    blocTest<InviteBloc, InviteState>(
      'a pro owner is ready even at a collaborator count that would cap a '
      'free tier',
      build: () {
        when(() => monetization.isProUser()).thenAnswer((_) async => true);
        when(() => pieceRepository.getPiece(pieceId)).thenAnswer(
          (_) async => Success(
            piece(collaborators: const [Collaborator(uid: 's1')]),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const InviteSheetOpened()),
      skip: 1,
      expect: () => [
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.ready,
        ),
      ],
    );

    blocTest<InviteBloc, InviteState>(
      'a free-tier owner under the per-piece cap is ready',
      build: () {
        when(() => monetization.isProUser()).thenAnswer((_) async => false);
        when(
          () => pieceRepository.getPiece(pieceId),
        ).thenAnswer((_) async => Success(piece()));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const InviteSheetOpened()),
      skip: 1,
      expect: () => [
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.ready,
        ),
      ],
    );

    blocTest<InviteBloc, InviteState>(
      'a free-tier owner already at the per-piece cap requires the paywall',
      build: () {
        when(() => monetization.isProUser()).thenAnswer((_) async => false);
        when(() => pieceRepository.getPiece(pieceId)).thenAnswer(
          (_) async => Success(
            piece(collaborators: const [Collaborator(uid: 's1')]),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const InviteSheetOpened()),
      skip: 1,
      expect: () => [
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.paywallRequired,
        ),
      ],
    );

    blocTest<InviteBloc, InviteState>(
      'typing an email that resolves surfaces the recipient (AC-1)',
      build: () {
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
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const InviteSheetOpened());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const InviteEmailChanged(email));
      },
      skip: 2,
      expect: () => [
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.lookingUp,
        ),
        isA<InviteState>()
            .having((s) => s.status, 'status', InviteStatus.resolved)
            .having((s) => s.recipient, 'recipient', recipient),
      ],
    );

    blocTest<InviteBloc, InviteState>(
      'typing an email with no discoverable account surfaces the link '
      'fallback (AC-3)',
      build: () {
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
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const InviteSheetOpened());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const InviteEmailChanged(email));
      },
      skip: 2,
      expect: () => [
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.lookingUp,
        ),
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.notFound,
        ),
      ],
    );

    blocTest<InviteBloc, InviteState>(
      'typing an email that is already a collaborator surfaces that',
      build: () {
        when(() => monetization.isProUser()).thenAnswer((_) async => true);
        when(
          () => pieceRepository.getPiece(pieceId),
        ).thenAnswer((_) async => Success(piece()));
        when(
          () => collaboratorInviteService.lookupInvitee(
            pieceId: pieceId,
            email: email,
          ),
        ).thenAnswer((_) async => const Success(AlreadyCollaborator()));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const InviteSheetOpened());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const InviteEmailChanged(email));
      },
      skip: 2,
      expect: () => [
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.lookingUp,
        ),
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.alreadyCollaborator,
        ),
      ],
    );

    blocTest<InviteBloc, InviteState>(
      'sending a resolved recipient succeeds',
      build: () {
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
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const InviteSheetOpened());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const InviteEmailChanged(email));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const InviteSendRequested());
      },
      skip: 4,
      expect: () => [
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.sending,
        ),
        isA<InviteState>()
            .having((s) => s.status, 'status', InviteStatus.sent)
            .having((s) => s.recipient, 'recipient', recipient),
      ],
      verify: (_) {
        verify(
          () => collaboratorInviteService.sendInvite(
            pieceId: pieceId,
            ownerId: ownerId,
            email: email,
            ownerName: any(named: 'ownerName'),
          ),
        ).called(1);
      },
    );

    blocTest<InviteBloc, InviteState>(
      'a send request is ignored while gated by the paywall, and never '
      'reaches the gateway (AC-6)',
      build: () {
        when(() => monetization.isProUser()).thenAnswer((_) async => false);
        when(() => pieceRepository.getPiece(pieceId)).thenAnswer(
          (_) async => Success(
            piece(collaborators: const [Collaborator(uid: 's1')]),
          ),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const InviteSheetOpened());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const InviteSendRequested());
      },
      skip: 2,
      expect: () => <Matcher>[],
      verify: (_) {
        verifyNever(
          () => collaboratorInviteService.sendInvite(
            pieceId: any(named: 'pieceId'),
            ownerId: any(named: 'ownerId'),
            email: any(named: 'email'),
            ownerName: any(named: 'ownerName'),
          ),
        );
      },
    );

    blocTest<InviteBloc, InviteState>(
      'the link fallback is available from notFound and surfaces a link',
      build: () {
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
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const InviteSheetOpened());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const InviteEmailChanged(email));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const InviteLinkCreateRequested());
      },
      skip: 4,
      expect: () => [
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.sending,
        ),
        isA<InviteState>()
            .having((s) => s.status, 'status', InviteStatus.sent)
            .having((s) => s.link?.token, 'link.token', 'tok'),
      ],
    );

    blocTest<InviteBloc, InviteState>(
      'a link-create failure surfaces the error and reverts to the prior '
      'status',
      build: () {
        when(() => monetization.isProUser()).thenAnswer((_) async => true);
        when(
          () => pieceRepository.getPiece(pieceId),
        ).thenAnswer((_) async => Success(piece()));
        when(
          () => inviteService.createInvite(
            ownerId: ownerId,
            pieceId: pieceId,
            ownerName: any(named: 'ownerName'),
          ),
        ).thenAnswer(
          (_) async => const ResultFailure<InviteLink>(InviteException('boom')),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const InviteSheetOpened());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const InviteLinkCreateRequested());
      },
      skip: 2,
      expect: () => [
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.sending,
        ),
        isA<InviteState>()
            .having((s) => s.status, 'status', InviteStatus.ready)
            .having((s) => s.error, 'error', contains('boom')),
      ],
    );
  });
}
