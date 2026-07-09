import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:feature_library/feature_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pieces/pieces.dart';

class MockPieceRepository extends Mock implements PieceRepository {}

void main() {
  group('LibraryBloc', () {
    const ownerId = 'owner-1';
    const collaboratorId = 'collaborator-1';

    late MockPieceRepository repository;
    late StreamController<List<Piece>> piecesController;

    Piece piece({
      String id = 'p1',
      List<Collaborator> collaborators = const [
        Collaborator(uid: collaboratorId),
      ],
      DateTime? createdAt,
      DateTime? updatedAt,
    }) {
      final created = createdAt ?? DateTime(2024);
      return Piece(
        id: id,
        title: 'Nocturne',
        basePdfChecksum: 'checksum',
        basePdfPath: '/tmp/$id.pdf',
        ownerId: ownerId,
        collaborators: collaborators,
        createdAt: created,
        updatedAt: updatedAt ?? created,
      );
    }

    setUp(() {
      repository = MockPieceRepository();
      piecesController = StreamController<List<Piece>>.broadcast();
      when(
        () => repository.watchPieces(),
      ).thenAnswer((_) => piecesController.stream);
    });

    tearDown(() async {
      await piecesController.close();
    });

    test('initial state carries the given currentUserId and no pieces', () {
      final bloc = LibraryBloc(
        pieceRepository: repository,
        currentUserId: ownerId,
      );
      addTearDown(bloc.close);
      expect(bloc.state.status, LibraryStatus.loading);
      expect(bloc.state.currentUserId, ownerId);
      expect(bloc.state.pieces, isEmpty);
    });

    blocTest<LibraryBloc, LibraryState>(
      'emits ready with pieces once the repository stream emits',
      build: () => LibraryBloc(
        pieceRepository: repository,
        currentUserId: ownerId,
      ),
      act: (bloc) async {
        bloc.add(const LibraryStarted());
        await Future<void>.delayed(Duration.zero);
        piecesController.add([piece()]);
      },
      expect: () => [
        isA<LibraryState>().having(
          (s) => s.status,
          'status',
          LibraryStatus.loading,
        ),
        isA<LibraryState>()
            .having((s) => s.status, 'status', LibraryStatus.ready)
            .having((s) => s.pieces.length, 'pieces.length', 1),
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'emits failure when the repository stream errors',
      build: () => LibraryBloc(
        pieceRepository: repository,
        currentUserId: ownerId,
      ),
      act: (bloc) async {
        bloc.add(const LibraryStarted());
        await Future<void>.delayed(Duration.zero);
        piecesController.addError(StateError('boom'));
      },
      skip: 1,
      expect: () => [
        isA<LibraryState>().having(
          (s) => s.status,
          'status',
          LibraryStatus.failure,
        ),
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'PieceViewed clears the unread indicator for that piece',
      build: () => LibraryBloc(
        pieceRepository: repository,
        currentUserId: ownerId,
      ),
      act: (bloc) async {
        bloc.add(const LibraryStarted());
        await Future<void>.delayed(Duration.zero);
        piecesController.add([
          piece(createdAt: DateTime(2024), updatedAt: DateTime(2024, 1, 2)),
        ]);
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PieceViewed('p1'));
      },
      skip: 1,
      expect: () => [
        isA<LibraryState>().having(
          (s) => s.isUnread(s.pieces.single),
          'isUnread',
          true,
        ),
        isA<LibraryState>().having(
          (s) => s.isUnread(s.pieces.single),
          'isUnread',
          false,
        ),
      ],
    );

    group('ownership partitioning', () {
      test('myPieces returns every piece this user owns', () {
        final state = const LibraryState.initial(currentUserId: ownerId)
            .copyWith(
              status: LibraryStatus.ready,
              pieces: [
                piece(),
                piece(id: 'p2', collaborators: const []),
              ],
            );

        expect(state.myPieces.map((p) => p.id), ['p1', 'p2']);
        // The owner is never their own collaborator.
        expect(state.sharedWithMe, isEmpty);
      });

      test(
        'sharedWithMe returns only pieces this user collaborates on, not '
        'ones they own',
        () {
          final state =
              const LibraryState.initial(
                currentUserId: collaboratorId,
              ).copyWith(
                status: LibraryStatus.ready,
                pieces: [
                  piece(),
                  piece(
                    id: 'p2',
                    collaborators: const [
                      Collaborator(uid: 'someone-else'),
                    ],
                  ),
                ],
              );

          expect(state.sharedWithMe.map((p) => p.id), ['p1']);
          expect(state.myPieces, isEmpty);
        },
      );

      test(
        'sharedWithMe sees a piece even as its SECOND collaborator (AC-4)',
        () {
          final shared = piece(
            collaborators: const [
              Collaborator(uid: 'collaborator-a'),
              Collaborator(uid: 'collaborator-b'),
            ],
          );
          final state = const LibraryState.initial(
            currentUserId: 'collaborator-b',
          ).copyWith(status: LibraryStatus.ready, pieces: [shared]);

          expect(state.sharedWithMe.map((p) => p.id), ['p1']);
        },
      );

      test(
        'a piece with multiple collaborators is owned by neither, so it '
        'never appears in the owner-only-viewer myPieces for a third party',
        () {
          final shared = piece(
            collaborators: const [
              Collaborator(uid: 'collaborator-a'),
              Collaborator(uid: 'collaborator-b'),
            ],
          );
          final state = const LibraryState.initial(
            currentUserId: 'collaborator-a',
          ).copyWith(status: LibraryStatus.ready, pieces: [shared]);

          expect(state.myPieces, isEmpty);
        },
      );
    });

    test('myPieces/sharedWithMe are both empty with no pieces', () {
      final state = const LibraryState.initial(
        currentUserId: ownerId,
      ).copyWith(status: LibraryStatus.ready);

      expect(state.myPieces, isEmpty);
      expect(state.sharedWithMe, isEmpty);
    });
  });
}
