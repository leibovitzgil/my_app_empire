import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/library/library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPieceRepository extends Mock implements PieceRepository {}

void main() {
  group('LibraryBloc', () {
    const ownerId = 'owner-1';
    const collaboratorId = 'collaborator-1';

    late MockPieceRepository repository;
    late StreamController<List<Piece>> piecesController;
    late StreamController<Map<String, DateTime>> readsController;

    Piece piece({
      String id = 'p1',
      String title = 'Nocturne',
      String pieceOwnerId = ownerId,
      List<Collaborator> collaborators = const [
        Collaborator(uid: collaboratorId),
      ],
      DateTime? createdAt,
      DateTime? updatedAt,
    }) {
      final created = createdAt ?? DateTime(2024);
      return Piece(
        id: id,
        title: title,
        basePdfChecksum: 'checksum',
        basePdfPath: '/tmp/$id.pdf',
        ownerId: pieceOwnerId,
        collaborators: collaborators,
        createdAt: created,
        updatedAt: updatedAt ?? created,
      );
    }

    setUp(() {
      repository = MockPieceRepository();
      piecesController = StreamController<List<Piece>>.broadcast();
      readsController = StreamController<Map<String, DateTime>>.broadcast();
      when(
        () => repository.watchPieces(),
      ).thenAnswer((_) => piecesController.stream);
      when(
        () => repository.watchReads(),
      ).thenAnswer((_) => readsController.stream);
      when(
        () => repository.markOpened(any()),
      ).thenAnswer((_) async => const Success<void>(null));
    });

    tearDown(() async {
      await piecesController.close();
      await readsController.close();
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
      'PieceViewed clears the unread dot for a shared piece and persists it',
      // The current user is a collaborator here, so the piece is shared with
      // them and can carry an unread dot (an owner's own piece never does).
      build: () => LibraryBloc(
        pieceRepository: repository,
        currentUserId: collaboratorId,
      ),
      act: (bloc) async {
        bloc.add(const LibraryStarted());
        await Future<void>.delayed(Duration.zero);
        // Shared, never opened → unread.
        piecesController.add([piece(updatedAt: DateTime(2024, 1, 2))]);
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PieceViewed('p1'));
      },
      skip: 1,
      expect: () => [
        isA<LibraryState>().having(
          (s) => s.isUnread(s.pieces.single),
          'isUnread (never opened)',
          true,
        ),
        isA<LibraryState>().having(
          (s) => s.isUnread(s.pieces.single),
          'isUnread (just opened)',
          false,
        ),
      ],
      verify: (_) => verify(() => repository.markOpened('p1')).called(1),
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

    group('filter/search/sort events', () {
      blocTest<LibraryBloc, LibraryState>(
        'LibraryFilterChanged updates filter',
        build: () =>
            LibraryBloc(pieceRepository: repository, currentUserId: ownerId),
        act: (bloc) => bloc.add(const LibraryFilterChanged(LibraryFilter.mine)),
        expect: () => [
          isA<LibraryState>().having(
            (s) => s.filter,
            'filter',
            LibraryFilter.mine,
          ),
        ],
      );

      blocTest<LibraryBloc, LibraryState>(
        'LibrarySearchChanged updates query',
        build: () =>
            LibraryBloc(pieceRepository: repository, currentUserId: ownerId),
        act: (bloc) => bloc.add(const LibrarySearchChanged('noct')),
        expect: () => [
          isA<LibraryState>().having((s) => s.query, 'query', 'noct'),
        ],
      );

      blocTest<LibraryBloc, LibraryState>(
        'LibrarySortChanged updates sort',
        build: () =>
            LibraryBloc(pieceRepository: repository, currentUserId: ownerId),
        act: (bloc) => bloc.add(const LibrarySortChanged(LibrarySort.title)),
        expect: () => [
          isA<LibraryState>().having(
            (s) => s.sort,
            'sort',
            LibrarySort.title,
          ),
        ],
      );
    });

    group('visiblePieces filter/search/sort composition', () {
      test('defaults to LibraryFilter.all, showing every piece', () {
        final state =
            const LibraryState.initial(
              currentUserId: ownerId,
            ).copyWith(
              status: LibraryStatus.ready,
              pieces: [
                piece(updatedAt: DateTime(2024)),
                piece(id: 'p2', updatedAt: DateTime(2024, 1, 5)),
              ],
            );

        expect(state.visiblePieces.map((p) => p.id), ['p2', 'p1']);
      });

      test('LibraryFilter.mine narrows visiblePieces to owned pieces', () {
        final state =
            const LibraryState.initial(
              currentUserId: ownerId,
            ).copyWith(
              status: LibraryStatus.ready,
              filter: LibraryFilter.mine,
              pieces: [
                piece(),
                piece(
                  id: 'p2',
                  pieceOwnerId: 'someone-else',
                  collaborators: const [Collaborator(uid: ownerId)],
                ),
              ],
            );

        expect(state.visiblePieces.map((p) => p.id), ['p1']);
      });

      test(
        'LibraryFilter.shared narrows visiblePieces to shared-with-me pieces',
        () {
          final state =
              const LibraryState.initial(
                currentUserId: ownerId,
              ).copyWith(
                status: LibraryStatus.ready,
                filter: LibraryFilter.shared,
                pieces: [
                  piece(),
                  piece(
                    id: 'p2',
                    pieceOwnerId: 'someone-else',
                    collaborators: const [Collaborator(uid: ownerId)],
                  ),
                ],
              );

          expect(state.visiblePieces.map((p) => p.id), ['p2']);
        },
      );

      test(
        'LibraryFilter.favorites is always empty, regardless of pieces',
        () {
          final state =
              const LibraryState.initial(
                currentUserId: ownerId,
              ).copyWith(
                status: LibraryStatus.ready,
                filter: LibraryFilter.favorites,
                pieces: [piece()],
              );

          expect(state.visiblePieces, isEmpty);
          expect(state.favoritePieces, isEmpty);
        },
      );

      test('a blank query behaves the same as an empty one', () {
        final state =
            const LibraryState.initial(
              currentUserId: ownerId,
            ).copyWith(
              status: LibraryStatus.ready,
              query: '   ',
              pieces: [piece(title: 'Clair de Lune')],
            );

        expect(state.visiblePieces.map((p) => p.id), ['p1']);
      });

      test('query narrows to titles containing it, case-insensitively', () {
        final state =
            const LibraryState.initial(
              currentUserId: ownerId,
            ).copyWith(
              status: LibraryStatus.ready,
              query: 'CLAIR',
              pieces: [
                piece(title: 'Clair de Lune'),
                piece(id: 'p2'),
              ],
            );

        expect(state.visiblePieces.map((p) => p.id), ['p1']);
      });

      test(
        'query narrows visibleMyPieces/visibleSharedPieces independently',
        () {
          final state =
              const LibraryState.initial(
                currentUserId: ownerId,
              ).copyWith(
                status: LibraryStatus.ready,
                query: 'noct',
                pieces: [
                  piece(title: 'Clair de Lune'),
                  piece(id: 'p2'),
                  piece(
                    id: 'p3',
                    title: 'Nocturne (shared)',
                    pieceOwnerId: 'someone-else',
                    collaborators: const [Collaborator(uid: ownerId)],
                  ),
                ],
              );

          expect(state.visibleMyPieces.map((p) => p.id), ['p2']);
          expect(state.visibleSharedPieces.map((p) => p.id), ['p3']);
        },
      );

      test(
        'LibrarySort.recentlyUpdated (the default) orders by updatedAt '
        'descending',
        () {
          final state =
              const LibraryState.initial(
                currentUserId: ownerId,
              ).copyWith(
                status: LibraryStatus.ready,
                pieces: [
                  piece(updatedAt: DateTime(2024)),
                  piece(id: 'p2', updatedAt: DateTime(2024, 1, 10)),
                  piece(id: 'p3', updatedAt: DateTime(2024, 1, 5)),
                ],
              );

          expect(state.visiblePieces.map((p) => p.id), ['p2', 'p3', 'p1']);
        },
      );

      test('recentlyUpdated ties break on id for deterministic order', () {
        final tie = DateTime(2024);
        final state =
            const LibraryState.initial(
              currentUserId: ownerId,
            ).copyWith(
              status: LibraryStatus.ready,
              pieces: [
                piece(id: 'b', updatedAt: tie),
                piece(id: 'a', updatedAt: tie),
              ],
            );

        expect(state.visiblePieces.map((p) => p.id), ['a', 'b']);
      });

      test('LibrarySort.recentlyAdded orders by createdAt descending', () {
        final state =
            const LibraryState.initial(
              currentUserId: ownerId,
            ).copyWith(
              status: LibraryStatus.ready,
              sort: LibrarySort.recentlyAdded,
              pieces: [
                piece(createdAt: DateTime(2024)),
                piece(id: 'p2', createdAt: DateTime(2024, 1, 10)),
              ],
            );

        expect(state.visiblePieces.map((p) => p.id), ['p2', 'p1']);
      });

      test(
        'LibrarySort.title orders alphabetically, case-insensitively',
        () {
          final state =
              const LibraryState.initial(
                currentUserId: ownerId,
              ).copyWith(
                status: LibraryStatus.ready,
                sort: LibrarySort.title,
                pieces: [
                  piece(title: 'zebra'),
                  piece(id: 'p2', title: 'Apple'),
                  piece(id: 'p3', title: 'mango'),
                ],
              );

          expect(state.visiblePieces.map((p) => p.id), ['p2', 'p3', 'p1']);
        },
      );

      test('filter, search and sort all compose together', () {
        final state =
            const LibraryState.initial(
              currentUserId: ownerId,
            ).copyWith(
              status: LibraryStatus.ready,
              filter: LibraryFilter.mine,
              query: 'sonata',
              sort: LibrarySort.title,
              pieces: [
                piece(title: 'Sonata no. 2'),
                piece(id: 'p2', title: 'Sonata no. 1'),
                piece(id: 'p3'),
                piece(
                  id: 'p4',
                  title: 'Sonata (shared)',
                  pieceOwnerId: 'someone-else',
                  collaborators: const [Collaborator(uid: ownerId)],
                ),
              ],
            );

        expect(state.visiblePieces.map((p) => p.id), ['p2', 'p1']);
      });

      test(
        'unreadSharedCount counts shared pieces changed since last open',
        () {
          Piece shared(String id) => piece(
            id: id,
            pieceOwnerId: 'someone-else',
            collaborators: const [Collaborator(uid: ownerId)],
            updatedAt: DateTime(2024, 1, 2),
          );
          final state = const LibraryState.initial(currentUserId: ownerId)
              .copyWith(
                status: LibraryStatus.ready,
                pieces: [
                  // Owned + updated: an owner's own sheet never dots.
                  piece(updatedAt: DateTime(2024, 1, 2)),
                  shared('p2'), // never opened → unread
                  shared('p3'), // opened after its update → read
                  shared('p4'), // opened before its update → unread again
                ],
                lastOpenedAt: {
                  'p3': DateTime(2024, 1, 3), // after p3's update
                  'p4': DateTime(2024), // before p4's update
                },
              );

          // p2 (never opened) + p4 (stale watermark); p1 owned, p3 read.
          expect(state.unreadSharedCount, 2);
          expect(state.isUnread(state.myPieces.single), isFalse);
        },
      );
    });
  });
}
