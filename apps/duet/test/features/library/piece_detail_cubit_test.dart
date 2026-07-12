import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/library/library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPieceRepository extends Mock implements PieceRepository {}

void main() {
  group('PieceDetailCubit', () {
    const ownerId = 'owner-1';
    const collaboratorId = 'collaborator-1';

    final ownedPiece = Piece(
      id: 'p1',
      title: 'Nocturne',
      basePdfChecksum: 'checksum',
      basePdfPath: '/tmp/p1.pdf',
      ownerId: ownerId,
      collaborators: const [Collaborator(uid: collaboratorId)],
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    late MockPieceRepository repository;

    setUp(() {
      repository = MockPieceRepository();
    });

    blocTest<PieceDetailCubit, PieceDetailState>(
      'load resolves the piece and the owner role',
      build: () {
        when(
          () => repository.getPiece('p1'),
        ).thenAnswer((_) async => Success(ownedPiece));
        return PieceDetailCubit(
          pieceRepository: repository,
          currentUserId: ownerId,
        );
      },
      act: (cubit) => cubit.load('p1'),
      expect: () => [
        isA<PieceDetailState>().having(
          (s) => s.status,
          'status',
          PieceDetailStatus.loading,
        ),
        isA<PieceDetailState>()
            .having((s) => s.status, 'status', PieceDetailStatus.ready)
            .having((s) => s.piece, 'piece', ownedPiece)
            .having((s) => s.currentRole, 'currentRole', PieceRole.owner),
      ],
    );

    blocTest<PieceDetailCubit, PieceDetailState>(
      'load resolves the collaborator role for the paired collaborator',
      build: () {
        when(
          () => repository.getPiece('p1'),
        ).thenAnswer((_) async => Success(ownedPiece));
        return PieceDetailCubit(
          pieceRepository: repository,
          currentUserId: collaboratorId,
        );
      },
      act: (cubit) => cubit.load('p1'),
      skip: 1,
      expect: () => [
        isA<PieceDetailState>().having(
          (s) => s.currentRole,
          'currentRole',
          PieceRole.collaborator,
        ),
      ],
    );

    blocTest<PieceDetailCubit, PieceDetailState>(
      'load surfaces a failure for an unknown piece',
      build: () {
        when(() => repository.getPiece('missing')).thenAnswer(
          (_) async => ResultFailure(StateError('Unknown piece: missing')),
        );
        return PieceDetailCubit(
          pieceRepository: repository,
          currentUserId: ownerId,
        );
      },
      act: (cubit) => cubit.load('missing'),
      skip: 1,
      expect: () => [
        isA<PieceDetailState>().having(
          (s) => s.status,
          'status',
          PieceDetailStatus.failure,
        ),
      ],
    );

    blocTest<PieceDetailCubit, PieceDetailState>(
      'rename updates the loaded piece on success',
      build: () {
        when(
          () => repository.getPiece('p1'),
        ).thenAnswer((_) async => Success(ownedPiece));
        when(
          () => repository.renamePiece('p1', 'New title'),
        ).thenAnswer((_) async => const Success<void>(null));
        return PieceDetailCubit(
          pieceRepository: repository,
          currentUserId: ownerId,
        );
      },
      act: (cubit) async {
        await cubit.load('p1');
        await cubit.rename('New title');
      },
      skip: 2,
      expect: () => [
        isA<PieceDetailState>().having(
          (s) => s.piece?.title,
          'piece.title',
          'New title',
        ),
      ],
    );

    blocTest<PieceDetailCubit, PieceDetailState>(
      'delete surfaces deleted:true on success',
      build: () {
        when(
          () => repository.getPiece('p1'),
        ).thenAnswer((_) async => Success(ownedPiece));
        when(
          () => repository.deletePiece('p1'),
        ).thenAnswer((_) async => const Success<void>(null));
        return PieceDetailCubit(
          pieceRepository: repository,
          currentUserId: ownerId,
        );
      },
      act: (cubit) async {
        await cubit.load('p1');
        await cubit.delete();
      },
      skip: 2,
      expect: () => [
        isA<PieceDetailState>().having((s) => s.deleted, 'deleted', true),
      ],
    );

    blocTest<PieceDetailCubit, PieceDetailState>(
      'leave surfaces an actionable error on failure',
      build: () {
        when(
          () => repository.getPiece('p1'),
        ).thenAnswer((_) async => Success(ownedPiece));
        when(() => repository.leavePiece('p1')).thenAnswer(
          (_) async => ResultFailure<void>(
            StateError('The owner cannot leave their own piece'),
          ),
        );
        return PieceDetailCubit(
          pieceRepository: repository,
          currentUserId: ownerId,
        );
      },
      act: (cubit) async {
        await cubit.load('p1');
        await cubit.leave();
      },
      skip: 2,
      expect: () => [
        isA<PieceDetailState>()
            .having((s) => s.left, 'left', false)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );
  });
}
