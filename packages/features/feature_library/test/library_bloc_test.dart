import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:feature_library/feature_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pieces/pieces.dart';

class MockPieceRepository extends Mock implements PieceRepository {}

void main() {
  group('LibraryBloc', () {
    const teacherId = 'teacher-1';
    const studentId = 'student-1';

    late MockPieceRepository repository;
    late StreamController<List<Piece>> piecesController;

    Piece piece({
      String id = 'p1',
      String? student = studentId,
      DateTime? createdAt,
      DateTime? updatedAt,
    }) {
      final created = createdAt ?? DateTime(2024);
      return Piece(
        id: id,
        title: 'Nocturne',
        basePdfChecksum: 'checksum',
        basePdfPath: '/tmp/$id.pdf',
        teacherId: teacherId,
        studentId: student,
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

    test('initial state carries the resolved role and no pieces', () {
      final bloc = LibraryBloc(
        pieceRepository: repository,
        currentUserId: teacherId,
        currentRole: PieceRole.teacher,
      );
      addTearDown(bloc.close);
      expect(bloc.state.status, LibraryStatus.loading);
      expect(bloc.state.currentRole, PieceRole.teacher);
      expect(bloc.state.pieces, isEmpty);
    });

    blocTest<LibraryBloc, LibraryState>(
      'emits ready with pieces once the repository stream emits',
      build: () => LibraryBloc(
        pieceRepository: repository,
        currentUserId: teacherId,
        currentRole: PieceRole.teacher,
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
        currentUserId: teacherId,
        currentRole: PieceRole.teacher,
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
        currentUserId: teacherId,
        currentRole: PieceRole.teacher,
      ),
      act: (bloc) async {
        bloc.add(const LibraryStarted());
        await Future<void>.delayed(Duration.zero);
        piecesController.add([
          piece(
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024, 1, 2),
          ),
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

    group('role-aware grouping', () {
      test("piecesByStudent groups a teacher's pieces by student id", () {
        final state =
            const LibraryState.initial(
              currentUserId: teacherId,
              currentRole: PieceRole.teacher,
            ).copyWith(
              status: LibraryStatus.ready,
              pieces: [
                piece(),
                piece(id: 'p2', student: 'student-2'),
                piece(id: 'p3', student: null),
              ],
            );

        final grouped = state.piecesByStudent;
        expect(grouped[studentId]!.map((p) => p.id), ['p1']);
        expect(grouped['student-2']!.map((p) => p.id), ['p2']);
        expect(grouped[null]!.map((p) => p.id), ['p3']);
        expect(state.unpairedPieces.map((p) => p.id), ['p3']);
      });

      test('sharedWithMe returns only pieces paired with this student', () {
        final state =
            const LibraryState.initial(
              currentUserId: studentId,
              currentRole: PieceRole.student,
            ).copyWith(
              status: LibraryStatus.ready,
              pieces: [
                piece(),
                piece(id: 'p2', student: 'someone-else'),
              ],
            );

        expect(state.sharedWithMe.map((p) => p.id), ['p1']);
      });

      test(
        'piecesByStudent groups a piece under EVERY one of its '
        'collaborators (AC-4)',
        () {
          final shared = Piece(
            id: 'p1',
            title: 'Nocturne',
            basePdfChecksum: 'checksum',
            basePdfPath: '/tmp/p1.pdf',
            teacherId: teacherId,
            collaborators: const [
              Collaborator(uid: 'student-1'),
              Collaborator(uid: 'student-2'),
            ],
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          );
          final state = const LibraryState.initial(
            currentUserId: teacherId,
            currentRole: PieceRole.teacher,
          ).copyWith(status: LibraryStatus.ready, pieces: [shared]);

          final grouped = state.piecesByStudent;
          expect(grouped['student-1']!.map((p) => p.id), ['p1']);
          expect(grouped['student-2']!.map((p) => p.id), ['p1']);
        },
      );

      test(
        'sharedWithMe sees a piece even as its SECOND collaborator (AC-4)',
        () {
          final shared = Piece(
            id: 'p1',
            title: 'Nocturne',
            basePdfChecksum: 'checksum',
            basePdfPath: '/tmp/p1.pdf',
            teacherId: teacherId,
            collaborators: const [
              Collaborator(uid: 'student-1'),
              Collaborator(uid: 'student-2'),
            ],
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          );
          final state = const LibraryState.initial(
            currentUserId: 'student-2',
            currentRole: PieceRole.student,
          ).copyWith(status: LibraryStatus.ready, pieces: [shared]);

          expect(state.sharedWithMe.map((p) => p.id), ['p1']);
        },
      );
    });

    test('empty-state expectations per role are reachable via state', () {
      final teacherState = const LibraryState.initial(
        currentUserId: teacherId,
        currentRole: PieceRole.teacher,
      ).copyWith(status: LibraryStatus.ready);
      expect(teacherState.piecesByStudent, isEmpty);

      final studentState = const LibraryState.initial(
        currentUserId: studentId,
        currentRole: PieceRole.student,
      ).copyWith(status: LibraryStatus.ready);
      expect(studentState.sharedWithMe, isEmpty);
    });
  });
}
