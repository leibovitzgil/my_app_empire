import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';

class MockInviteService extends Mock implements InviteService {}

class MockPieceRepository extends Mock implements PieceRepository {}

class MockMonetizationService extends Mock implements MonetizationService {}

void main() {
  group('AcceptInviteCubit', () {
    const token = 'tok-1';
    const collaboratorId = 'collaborator-1';
    const collaboratorEmail = 'collaborator@example.com';
    const details = InviteDetails(
      pieceId: 'p1',
      pieceTitle: 'Nocturne',
      ownerId: 'owner-1',
    );

    late MockInviteService inviteService;
    late MockPieceRepository pieceRepository;
    late MockMonetizationService monetization;

    Piece piece({List<Collaborator> collaborators = const []}) => Piece(
      id: 'p1',
      title: 'Nocturne',
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
    });

    AcceptInviteCubit buildCubit() => AcceptInviteCubit(
      inviteService: inviteService,
      pieceRepository: pieceRepository,
      monetizationService: monetization,
      token: token,
      collaboratorId: collaboratorId,
      collaboratorEmail: collaboratorEmail,
    );

    blocTest<AcceptInviteCubit, AcceptInviteState>(
      'load resolves the invite details and is ready under the cap',
      build: () {
        when(
          () => inviteService.resolveInvite(token),
        ).thenAnswer((_) async => const Success(details));
        when(
          () => pieceRepository.getPiece('p1'),
        ).thenAnswer((_) async => Success(piece()));
        when(() => monetization.isProUser()).thenAnswer((_) async => false);
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AcceptInviteState>().having(
          (s) => s.status,
          'status',
          AcceptInviteStatus.loading,
        ),
        isA<AcceptInviteState>()
            .having((s) => s.status, 'status', AcceptInviteStatus.ready)
            .having((s) => s.details, 'details', details),
      ],
    );

    blocTest<AcceptInviteCubit, AcceptInviteState>(
      'load surfaces a failure for an invalid/expired token',
      build: () {
        when(() => inviteService.resolveInvite(token)).thenAnswer(
          (_) async => const ResultFailure<InviteDetails>(
            InviteException('This invite link is invalid or has expired.'),
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        isA<AcceptInviteState>()
            .having((s) => s.status, 'status', AcceptInviteStatus.failure)
            .having(
              (s) => s.error,
              'error',
              contains('invalid or has expired'),
            ),
      ],
    );

    blocTest<AcceptInviteCubit, AcceptInviteState>(
      'load surfaces the expired copy for a token past its TTL (M5.2)',
      build: () {
        when(() => inviteService.resolveInvite(token)).thenAnswer(
          (_) async => const ResultFailure<InviteDetails>(
            InviteException(
              'This invite link is invalid or has expired.',
              reason: InviteFailureReason.expired,
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        isA<AcceptInviteState>()
            .having((s) => s.status, 'status', AcceptInviteStatus.failure)
            .having(
              (s) => s.error,
              'error',
              contains('invalid or has expired'),
            ),
      ],
    );

    blocTest<AcceptInviteCubit, AcceptInviteState>(
      'load is ready when the piece read is denied — a fresh invitee '
      'cannot read a participant-gated piece under the cloud rules '
      '(M5.2); the accept callable re-asserts access instead',
      build: () {
        when(
          () => inviteService.resolveInvite(token),
        ).thenAnswer((_) async => const Success(details));
        when(() => pieceRepository.getPiece('p1')).thenAnswer(
          (_) async => const ResultFailure<Piece>(OwnershipViolation('p1')),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        isA<AcceptInviteState>()
            .having((s) => s.status, 'status', AcceptInviteStatus.ready)
            .having((s) => s.details, 'details', details)
            .having((s) => s.error, 'error', isNull),
      ],
    );

    blocTest<AcceptInviteCubit, AcceptInviteState>(
      'load surfaces alreadyCollaborator when the accepter already has '
      'access',
      build: () {
        when(
          () => inviteService.resolveInvite(token),
        ).thenAnswer((_) async => const Success(details));
        when(() => pieceRepository.getPiece('p1')).thenAnswer(
          (_) async => Success(
            piece(collaborators: const [Collaborator(uid: collaboratorId)]),
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        isA<AcceptInviteState>().having(
          (s) => s.status,
          'status',
          AcceptInviteStatus.alreadyCollaborator,
        ),
      ],
    );

    blocTest<AcceptInviteCubit, AcceptInviteState>(
      'load surfaces atCap when the piece is already at its collaborator '
      'cap (AC-11)',
      build: () {
        when(
          () => inviteService.resolveInvite(token),
        ).thenAnswer((_) async => const Success(details));
        when(() => pieceRepository.getPiece('p1')).thenAnswer(
          (_) async => Success(
            piece(collaborators: const [Collaborator(uid: 'someone-else')]),
          ),
        );
        when(() => monetization.isProUser()).thenAnswer((_) async => false);
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        isA<AcceptInviteState>().having(
          (s) => s.status,
          'status',
          AcceptInviteStatus.atCap,
        ),
      ],
    );

    blocTest<AcceptInviteCubit, AcceptInviteState>(
      'accept moves to accepted on success, recording uid and email (AC-2)',
      build: () {
        when(
          () => inviteService.resolveInvite(token),
        ).thenAnswer((_) async => const Success(details));
        when(
          () => pieceRepository.getPiece('p1'),
        ).thenAnswer((_) async => Success(piece()));
        when(() => monetization.isProUser()).thenAnswer((_) async => false);
        when(
          () => inviteService.acceptInvite(
            token,
            collaboratorId: collaboratorId,
            collaboratorName: any(named: 'collaboratorName'),
            collaboratorEmail: collaboratorEmail,
          ),
        ).thenAnswer((_) async => const Success<void>(null));
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.accept();
      },
      skip: 2,
      expect: () => [
        isA<AcceptInviteState>().having(
          (s) => s.status,
          'status',
          AcceptInviteStatus.accepting,
        ),
        isA<AcceptInviteState>().having(
          (s) => s.status,
          'status',
          AcceptInviteStatus.accepted,
        ),
      ],
      verify: (_) {
        verify(
          () => inviteService.acceptInvite(
            token,
            collaboratorId: collaboratorId,
            collaboratorName: any(named: 'collaboratorName'),
            collaboratorEmail: collaboratorEmail,
          ),
        ).called(1);
      },
    );

    blocTest<AcceptInviteCubit, AcceptInviteState>(
      'accept surfaces a failure and stays retryable',
      build: () {
        when(
          () => inviteService.resolveInvite(token),
        ).thenAnswer((_) async => const Success(details));
        when(
          () => pieceRepository.getPiece('p1'),
        ).thenAnswer((_) async => Success(piece()));
        when(() => monetization.isProUser()).thenAnswer((_) async => false);
        when(
          () => inviteService.acceptInvite(
            token,
            collaboratorId: collaboratorId,
            collaboratorName: any(named: 'collaboratorName'),
            collaboratorEmail: collaboratorEmail,
          ),
        ).thenAnswer(
          (_) async => const ResultFailure<void>(
            InviteException('This sheet already has a collaborator.'),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.accept();
      },
      skip: 2,
      expect: () => [
        isA<AcceptInviteState>().having(
          (s) => s.status,
          'status',
          AcceptInviteStatus.accepting,
        ),
        isA<AcceptInviteState>()
            .having((s) => s.status, 'status', AcceptInviteStatus.ready)
            .having(
              (s) => s.error,
              'error',
              contains('already has a collaborator'),
            ),
      ],
    );

    blocTest<AcceptInviteCubit, AcceptInviteState>(
      'a typed at-cap denial from accept maps to the atCap state, keeping '
      'the resolved details (M5.2: the cloud path re-asserts the cap '
      'server-side, where a fresh invitee could not pre-check it)',
      build: () {
        when(
          () => inviteService.resolveInvite(token),
        ).thenAnswer((_) async => const Success(details));
        when(() => pieceRepository.getPiece('p1')).thenAnswer(
          (_) async => const ResultFailure<Piece>(OwnershipViolation('p1')),
        );
        when(
          () => inviteService.acceptInvite(
            token,
            collaboratorId: collaboratorId,
            collaboratorName: any(named: 'collaboratorName'),
            collaboratorEmail: collaboratorEmail,
          ),
        ).thenAnswer(
          (_) async => const ResultFailure<void>(
            InviteException(
              'Free plan allows 1 collaborator. Upgrade to invite more.',
              reason: InviteFailureReason.atCap,
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.accept();
      },
      skip: 2,
      expect: () => [
        isA<AcceptInviteState>().having(
          (s) => s.status,
          'status',
          AcceptInviteStatus.accepting,
        ),
        isA<AcceptInviteState>()
            .having((s) => s.status, 'status', AcceptInviteStatus.atCap)
            .having((s) => s.details, 'details', details),
      ],
    );

    blocTest<AcceptInviteCubit, AcceptInviteState>(
      'a typed already-collaborator denial from accept maps to the '
      'alreadyCollaborator state (M5.2)',
      build: () {
        when(
          () => inviteService.resolveInvite(token),
        ).thenAnswer((_) async => const Success(details));
        when(() => pieceRepository.getPiece('p1')).thenAnswer(
          (_) async => const ResultFailure<Piece>(OwnershipViolation('p1')),
        );
        when(
          () => inviteService.acceptInvite(
            token,
            collaboratorId: collaboratorId,
            collaboratorName: any(named: 'collaboratorName'),
            collaboratorEmail: collaboratorEmail,
          ),
        ).thenAnswer(
          (_) async => const ResultFailure<void>(
            InviteException(
              'You already have access to this piece.',
              reason: InviteFailureReason.alreadyCollaborator,
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.accept();
      },
      skip: 2,
      expect: () => [
        isA<AcceptInviteState>().having(
          (s) => s.status,
          'status',
          AcceptInviteStatus.accepting,
        ),
        isA<AcceptInviteState>().having(
          (s) => s.status,
          'status',
          AcceptInviteStatus.alreadyCollaborator,
        ),
      ],
    );
  });
}
