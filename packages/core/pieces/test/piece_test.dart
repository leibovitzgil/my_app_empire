import 'package:flutter_test/flutter_test.dart';
import 'package:pieces/pieces.dart';

void main() {
  group('Piece', () {
    test('supports value equality', () {
      final now = DateTime(2024);
      final piece = Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'abc123',
        basePdfPath: '/pieces/p1.pdf',
        teacherId: 'teacher-1',
        createdAt: now,
        updatedAt: now,
      );

      expect(
        piece,
        Piece(
          id: 'p1',
          title: 'Clair de Lune',
          basePdfChecksum: 'abc123',
          basePdfPath: '/pieces/p1.pdf',
          teacherId: 'teacher-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    test('copyWith replaces only the given fields', () {
      final now = DateTime(2024);
      final piece = Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'abc123',
        basePdfPath: '/pieces/p1.pdf',
        teacherId: 'teacher-1',
        createdAt: now,
        updatedAt: now,
      );

      final renamed = piece.copyWith(title: 'Reverie');

      expect(renamed.title, 'Reverie');
      expect(renamed.id, piece.id);
      expect(renamed.teacherId, piece.teacherId);
    });

    test('collaborators defaults to empty, and names default to null', () {
      final now = DateTime(2024);
      final piece = Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'abc123',
        basePdfPath: '/pieces/p1.pdf',
        teacherId: 'teacher-1',
        createdAt: now,
        updatedAt: now,
      );

      expect(piece.collaborators, isEmpty);
      expect(piece.teacherName, isNull);
      expect(piece.studentId, isNull);
      expect(piece.studentName, isNull);
      expect(piece.collaboratorCount, 0);
      expect(piece.collaboratorIds, isEmpty);
      expect(piece.participantIds, ['teacher-1']);
    });

    test('collaborators participate in value equality', () {
      final now = DateTime(2024);
      Piece build(List<Collaborator> collaborators) => Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'abc123',
        basePdfPath: '/pieces/p1.pdf',
        teacherId: 'teacher-1',
        teacherName: 'Jane',
        collaborators: collaborators,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        build(const [Collaborator(uid: 'student-1', name: 'Sam')]),
        build(const [Collaborator(uid: 'student-1', name: 'Sam')]),
      );
      expect(
        build(const [Collaborator(uid: 'student-1', name: 'Sam')]),
        isNot(build(const [Collaborator(uid: 'student-1', name: 'Someone')])),
      );
    });

    test('copyWith preserves an existing name when not given a new one', () {
      final now = DateTime(2024);
      final piece = Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'abc123',
        basePdfPath: '/pieces/p1.pdf',
        teacherId: 'teacher-1',
        teacherName: 'Jane',
        createdAt: now,
        updatedAt: now,
      );

      final renamed = piece.copyWith(title: 'Reverie');

      expect(renamed.teacherName, 'Jane');
    });

    test('copyWith replaces collaborators when given', () {
      final now = DateTime(2024);
      final piece = Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'abc123',
        basePdfPath: '/pieces/p1.pdf',
        teacherId: 'teacher-1',
        teacherName: 'Jane',
        createdAt: now,
        updatedAt: now,
      );

      final updated = piece.copyWith(
        collaborators: const [Collaborator(uid: 'student-1', name: 'Sam')],
        teacherName: 'Jane Doe',
      );

      expect(updated.collaborators, [
        const Collaborator(uid: 'student-1', name: 'Sam'),
      ]);
      expect(updated.studentId, 'student-1');
      expect(updated.studentName, 'Sam');
      expect(updated.teacherName, 'Jane Doe');
      expect(updated.isCollaborator('student-1'), isTrue);
      expect(updated.isParticipant('student-1'), isTrue);
      expect(updated.isParticipant('teacher-1'), isTrue);
      expect(updated.isParticipant('someone-else'), isFalse);
    });

    test(
      'legacy studentId/studentName constructor sugar seeds one '
      'collaborator (back-compat, AC-10)',
      () {
        final now = DateTime(2024);
        final piece = Piece(
          id: 'p1',
          title: 'Clair de Lune',
          basePdfChecksum: 'abc123',
          basePdfPath: '/pieces/p1.pdf',
          teacherId: 'teacher-1',
          studentId: 'student-1',
          studentName: 'Sam',
          createdAt: now,
          updatedAt: now,
        );

        expect(piece.collaborators, [
          const Collaborator(uid: 'student-1', name: 'Sam'),
        ]);
        expect(piece.studentId, 'student-1');
        expect(piece.studentName, 'Sam');
        expect(piece.collaboratorCount, 1);
      },
    );

    test(
      'legacy copyWith(studentId:) sugar replaces only the first '
      'collaborator slot',
      () {
        final now = DateTime(2024);
        final piece = Piece(
          id: 'p1',
          title: 'Clair de Lune',
          basePdfChecksum: 'abc123',
          basePdfPath: '/pieces/p1.pdf',
          teacherId: 'teacher-1',
          collaborators: const [
            Collaborator(uid: 'student-1', name: 'Sam'),
            Collaborator(uid: 'student-2', name: 'Alex'),
          ],
          createdAt: now,
          updatedAt: now,
        );

        final updated = piece.copyWith(studentName: 'Samuel');

        expect(updated.collaborators, [
          const Collaborator(uid: 'student-1', name: 'Samuel'),
          const Collaborator(uid: 'student-2', name: 'Alex'),
        ]);
      },
    );

    test('multiple collaborators: ids/participants/count', () {
      final now = DateTime(2024);
      final piece = Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'abc123',
        basePdfPath: '/pieces/p1.pdf',
        teacherId: 'teacher-1',
        collaborators: const [
          Collaborator(uid: 'student-1'),
          Collaborator(uid: 'student-2'),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(piece.collaboratorCount, 2);
      expect(piece.collaboratorIds, ['student-1', 'student-2']);
      expect(piece.participantIds, ['teacher-1', 'student-1', 'student-2']);
      expect(piece.isCollaborator('student-2'), isTrue);
      expect(piece.isCollaborator('teacher-1'), isFalse);
      expect(piece.isParticipant('teacher-1'), isTrue);
      // The plain compat getters only ever surface the *first* collaborator.
      expect(piece.studentId, 'student-1');
    });
  });

  group('CollaboratorLimits', () {
    test('capFor returns the free/paid tier caps', () {
      expect(CollaboratorLimits.capFor(false), 1);
      expect(CollaboratorLimits.capFor(true), 8);
    });

    Piece pieceWith(int collaboratorCount) => Piece(
      id: 'p1',
      title: 'Clair de Lune',
      basePdfChecksum: 'abc123',
      basePdfPath: '/pieces/p1.pdf',
      teacherId: 'teacher-1',
      collaborators: [
        for (var i = 0; i < collaboratorCount; i++) Collaborator(uid: 's$i'),
      ],
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    test('isAtCap is false below the free-tier cap', () {
      expect(CollaboratorLimits.isAtCap(pieceWith(0), false), isFalse);
    });

    test('isAtCap is true at the free-tier cap', () {
      expect(CollaboratorLimits.isAtCap(pieceWith(1), false), isTrue);
    });

    test('isAtCap is false below the paid-tier cap', () {
      expect(CollaboratorLimits.isAtCap(pieceWith(7), true), isFalse);
    });

    test('isAtCap is true at the paid-tier cap', () {
      expect(CollaboratorLimits.isAtCap(pieceWith(8), true), isTrue);
    });

    test('isAtCap is per-piece, not library-wide', () {
      // Two separate one-collaborator pieces: each is independently at the
      // free cap; neither's count is affected by the other's.
      final pieceA = pieceWith(1);
      final pieceB = pieceWith(1);

      expect(CollaboratorLimits.isAtCap(pieceA, false), isTrue);
      expect(CollaboratorLimits.isAtCap(pieceB, false), isTrue);
      expect(pieceA.collaboratorCount, 1);
      expect(pieceB.collaboratorCount, 1);
    });
  });
}
