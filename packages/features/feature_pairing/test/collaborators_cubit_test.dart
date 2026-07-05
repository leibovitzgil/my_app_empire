import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pieces/pieces.dart';

class MockPieceRepository extends Mock implements PieceRepository {}

void main() {
  group('CollaboratorsCubit', () {
    const ownerId = 'teacher-1';
    const collaboratorA = Collaborator(uid: 'a', name: 'Alex');
    const collaboratorB = Collaborator(uid: 'b', name: 'Bo');

    late MockPieceRepository pieceRepository;
    late StreamController<List<Piece>> controller;

    Piece piece(List<Collaborator> collaborators) => Piece(
      id: 'p1',
      title: 'Nocturne',
      basePdfChecksum: 'c',
      basePdfPath: '/tmp/p.pdf',
      teacherId: ownerId,
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

    blocTest<CollaboratorsCubit, CollaboratorsState>(
      'reports the empty status for a piece with no collaborators yet',
      build: () => CollaboratorsCubit(
        pieceRepository: pieceRepository,
        pieceId: 'p1',
        currentUserId: ownerId,
      ),
      act: (_) => controller.add([piece(const [])]),
      expect: () => [
        isA<CollaboratorsState>()
            .having((s) => s.status, 'status', CollaboratorsStatus.empty)
            .having((s) => s.viewerIsOwner, 'viewerIsOwner', true),
      ],
    );

    blocTest<CollaboratorsCubit, CollaboratorsState>(
      'reports the roster and viewerIsOwner for the owner',
      build: () => CollaboratorsCubit(
        pieceRepository: pieceRepository,
        pieceId: 'p1',
        currentUserId: ownerId,
      ),
      act: (_) => controller.add([
        piece(const [collaboratorA, collaboratorB]),
      ]),
      expect: () => [
        isA<CollaboratorsState>()
            .having((s) => s.status, 'status', CollaboratorsStatus.success)
            .having(
              (s) => s.collaborators,
              'collaborators',
              const [collaboratorA, collaboratorB],
            )
            .having((s) => s.viewerIsOwner, 'viewerIsOwner', true),
      ],
    );

    blocTest<CollaboratorsCubit, CollaboratorsState>(
      'viewerIsOwner is false for a collaborator viewer',
      build: () => CollaboratorsCubit(
        pieceRepository: pieceRepository,
        pieceId: 'p1',
        currentUserId: 'a',
      ),
      act: (_) => controller.add([
        piece(const [collaboratorA]),
      ]),
      expect: () => [
        isA<CollaboratorsState>().having(
          (s) => s.viewerIsOwner,
          'viewerIsOwner',
          false,
        ),
      ],
    );

    blocTest<CollaboratorsCubit, CollaboratorsState>(
      'reports empty once the piece is no longer visible (left/removed)',
      build: () => CollaboratorsCubit(
        pieceRepository: pieceRepository,
        pieceId: 'p1',
        currentUserId: ownerId,
      ),
      act: (_) async {
        controller.add([
          piece(const [collaboratorA]),
        ]);
        await Future<void>.delayed(Duration.zero);
        controller.add(const []);
      },
      skip: 1,
      expect: () => [
        isA<CollaboratorsState>().having(
          (s) => s.status,
          'status',
          CollaboratorsStatus.empty,
        ),
      ],
    );

    blocTest<CollaboratorsCubit, CollaboratorsState>(
      'remove is a no-op for a non-owner viewer',
      build: () => CollaboratorsCubit(
        pieceRepository: pieceRepository,
        pieceId: 'p1',
        currentUserId: 'a',
      ),
      seed: () => const CollaboratorsState.initial().copyWith(
        status: CollaboratorsStatus.success,
        ownerId: ownerId,
        collaborators: const [collaboratorA, collaboratorB],
        viewerIsOwner: false,
      ),
      act: (cubit) => cubit.remove('b'),
      expect: () => <Matcher>[],
      verify: (_) {
        verifyNever(() => pieceRepository.removeCollaborator(any(), any()));
      },
    );

    blocTest<CollaboratorsCubit, CollaboratorsState>(
      'remove optimistically drops the row, then commits on success',
      build: () => CollaboratorsCubit(
        pieceRepository: pieceRepository,
        pieceId: 'p1',
        currentUserId: ownerId,
      ),
      seed: () => const CollaboratorsState.initial().copyWith(
        status: CollaboratorsStatus.success,
        ownerId: ownerId,
        collaborators: const [collaboratorA, collaboratorB],
        viewerIsOwner: true,
      ),
      setUp: () => when(
        () => pieceRepository.removeCollaborator('p1', 'b'),
      ).thenAnswer((_) async => const Success<void>(null)),
      act: (cubit) => cubit.remove('b'),
      expect: () => [
        isA<CollaboratorsState>().having(
          (s) => s.collaborators,
          'collaborators',
          const [collaboratorA],
        ),
      ],
      verify: (_) {
        verify(() => pieceRepository.removeCollaborator('p1', 'b')).called(1);
      },
    );

    blocTest<CollaboratorsCubit, CollaboratorsState>(
      'remove reverts the optimistic update on failure',
      build: () => CollaboratorsCubit(
        pieceRepository: pieceRepository,
        pieceId: 'p1',
        currentUserId: ownerId,
      ),
      seed: () => const CollaboratorsState.initial().copyWith(
        status: CollaboratorsStatus.success,
        ownerId: ownerId,
        collaborators: const [collaboratorA, collaboratorB],
        viewerIsOwner: true,
      ),
      setUp: () =>
          when(
            () => pieceRepository.removeCollaborator('p1', 'b'),
          ).thenAnswer(
            (_) async => const ResultFailure<void>('sync failed'),
          ),
      act: (cubit) => cubit.remove('b'),
      expect: () => [
        isA<CollaboratorsState>().having(
          (s) => s.collaborators,
          'collaborators',
          const [collaboratorA],
        ),
        isA<CollaboratorsState>()
            .having(
              (s) => s.collaborators,
              'collaborators',
              const [collaboratorA, collaboratorB],
            )
            .having((s) => s.error, 'error', contains('sync failed')),
      ],
    );

    blocTest<CollaboratorsCubit, CollaboratorsState>(
      'leave delegates to the repository',
      build: () => CollaboratorsCubit(
        pieceRepository: pieceRepository,
        pieceId: 'p1',
        currentUserId: 'a',
      ),
      setUp: () => when(
        () => pieceRepository.leavePiece('p1'),
      ).thenAnswer((_) async => const Success<void>(null)),
      act: (cubit) => cubit.leave(),
      expect: () => <Matcher>[],
      verify: (_) {
        verify(() => pieceRepository.leavePiece('p1')).called(1);
      },
    );
  });
}
