import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_library/feature_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pieces/pieces.dart';

class MockPieceRepository extends Mock implements PieceRepository {}

void main() {
  group('PieceDetailCubit', () {
    const teacherId = 'teacher-1';
    const studentId = 'student-1';

    final teacherPiece = Piece(
      id: 'p1',
      title: 'Nocturne',
      basePdfChecksum: 'checksum',
      basePdfPath: '/tmp/p1.pdf',
      teacherId: teacherId,
      studentId: studentId,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    late MockPieceRepository repository;

    setUp(() {
      repository = MockPieceRepository();
    });

    blocTest<PieceDetailCubit, PieceDetailState>(
      'load resolves the piece and the teacher role',
      build: () {
        when(
          () => repository.getPiece('p1'),
        ).thenAnswer((_) async => Success(teacherPiece));
        return PieceDetailCubit(
          pieceRepository: repository,
          currentUserId: teacherId,
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
            .having((s) => s.piece, 'piece', teacherPiece)
            .having((s) => s.currentRole, 'currentRole', PieceRole.teacher),
      ],
    );

    blocTest<PieceDetailCubit, PieceDetailState>(
      'load resolves the student role for the paired student',
      build: () {
        when(
          () => repository.getPiece('p1'),
        ).thenAnswer((_) async => Success(teacherPiece));
        return PieceDetailCubit(
          pieceRepository: repository,
          currentUserId: studentId,
        );
      },
      act: (cubit) => cubit.load('p1'),
      skip: 1,
      expect: () => [
        isA<PieceDetailState>().having(
          (s) => s.currentRole,
          'currentRole',
          PieceRole.student,
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
          currentUserId: teacherId,
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
        ).thenAnswer((_) async => Success(teacherPiece));
        when(
          () => repository.renamePiece('p1', 'New title'),
        ).thenAnswer((_) async => const Success<void>(null));
        return PieceDetailCubit(
          pieceRepository: repository,
          currentUserId: teacherId,
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
        ).thenAnswer((_) async => Success(teacherPiece));
        when(
          () => repository.deletePiece('p1'),
        ).thenAnswer((_) async => const Success<void>(null));
        return PieceDetailCubit(
          pieceRepository: repository,
          currentUserId: teacherId,
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
        ).thenAnswer((_) async => Success(teacherPiece));
        when(() => repository.leavePiece('p1')).thenAnswer(
          (_) async => ResultFailure<void>(
            StateError('The teacher owns this piece'),
          ),
        );
        return PieceDetailCubit(
          pieceRepository: repository,
          currentUserId: teacherId,
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
