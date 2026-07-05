import 'package:flutter_test/flutter_test.dart';
import 'package:pieces/pieces.dart';
import 'package:pieces/src/data/piece_mappers.dart';

void main() {
  test('pieceToJson / pieceFromJson round-trip', () {
    final piece = Piece(
      id: 'p1',
      title: 'Clair de Lune',
      basePdfChecksum: 'abc123',
      basePdfPath: '/pieces/p1.pdf',
      teacherId: 'teacher-1',
      collaborators: const [Collaborator(uid: 'student-1', name: 'Sam Smith')],
      teacherName: 'Jane Doe',
      createdAt: DateTime(2024, 1, 2, 3),
      updatedAt: DateTime(2024, 1, 3, 4),
    );

    final roundTripped = pieceFromJson(pieceToJson(piece));

    expect(roundTripped, piece);
    expect(roundTripped.teacherName, 'Jane Doe');
    expect(roundTripped.studentName, 'Sam Smith');
    expect(roundTripped.collaborators, piece.collaborators);
  });

  test('pieceToJson dual-writes legacy studentId/studentName', () {
    final piece = Piece(
      id: 'p1',
      title: 'Clair de Lune',
      basePdfChecksum: 'abc123',
      basePdfPath: '/pieces/p1.pdf',
      teacherId: 'teacher-1',
      collaborators: const [Collaborator(uid: 'student-1', name: 'Sam Smith')],
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    final json = pieceToJson(piece);

    expect(json['studentId'], 'student-1');
    expect(json['studentName'], 'Sam Smith');
    expect(json['collaborators'], [
      {'uid': 'student-1', 'name': 'Sam Smith', 'email': null},
    ]);
  });

  test('pieceFromJson handles no collaborators', () {
    final piece = Piece(
      id: 'p1',
      title: 'Solo piece',
      basePdfChecksum: 'abc123',
      basePdfPath: '/pieces/p1.pdf',
      teacherId: 'teacher-1',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    final roundTripped = pieceFromJson(pieceToJson(piece));

    expect(roundTripped.studentId, isNull);
    expect(roundTripped.collaborators, isEmpty);
    expect(roundTripped, piece);
  });

  test(
    'pieceFromJson decodes an old, pre-name JSON record without '
    'teacherName/studentName as null rather than throwing',
    () {
      final json = <String, dynamic>{
        'id': 'p1',
        'title': 'Persisted before names existed',
        'basePdfChecksum': 'abc123',
        'basePdfPath': '/pieces/p1.pdf',
        'teacherId': 'teacher-1',
        'studentId': 'student-1',
        'createdAt': DateTime(2024).toIso8601String(),
        'updatedAt': DateTime(2024).toIso8601String(),
        // Deliberately no `teacherName`/`studentName`/`collaborators` keys
        // at all, mirroring a record persisted before those fields existed.
      };

      final decoded = pieceFromJson(json);

      expect(decoded.id, 'p1');
      expect(decoded.studentId, 'student-1');
      expect(decoded.teacherName, isNull);
      expect(decoded.studentName, isNull);
    },
  );

  test(
    'legacy JSON (studentId only, no collaborators key) decodes to '
    'exactly one collaborator, losing no data (AC-10)',
    () {
      final json = <String, dynamic>{
        'id': 'p1',
        'title': 'Pre-migration piece',
        'basePdfChecksum': 'abc123',
        'basePdfPath': '/pieces/p1.pdf',
        'teacherId': 'teacher-1',
        'studentId': 'student-1',
        'studentName': 'Sam Smith',
        'createdAt': DateTime(2024).toIso8601String(),
        'updatedAt': DateTime(2024).toIso8601String(),
      };

      final decoded = pieceFromJson(json);

      expect(decoded.collaborators, [
        const Collaborator(uid: 'student-1', name: 'Sam Smith'),
      ]);
      expect(decoded.collaboratorCount, 1);
    },
  );

  test(
    'legacy JSON with no studentId at all decodes to an empty '
    'collaborators list',
    () {
      final json = <String, dynamic>{
        'id': 'p1',
        'title': 'Unpaired piece',
        'basePdfChecksum': 'abc123',
        'basePdfPath': '/pieces/p1.pdf',
        'teacherId': 'teacher-1',
        'createdAt': DateTime(2024).toIso8601String(),
        'updatedAt': DateTime(2024).toIso8601String(),
      };

      final decoded = pieceFromJson(json);

      expect(decoded.collaborators, isEmpty);
    },
  );

  test(
    'new JSON (collaborators key present) is read from collaborators, '
    'ignoring any stale legacy studentId shim',
    () {
      final json = <String, dynamic>{
        'id': 'p1',
        'title': 'Multi-collaborator piece',
        'basePdfChecksum': 'abc123',
        'basePdfPath': '/pieces/p1.pdf',
        'teacherId': 'teacher-1',
        'collaborators': [
          {'uid': 'student-1', 'name': 'Sam', 'email': 'sam@example.com'},
          {'uid': 'student-2', 'name': 'Alex', 'email': null},
        ],
        // A stale legacy shim naming only the first collaborator: proves
        // `collaborators` wins over it rather than the two conflicting.
        'studentId': 'student-1',
        'studentName': 'Sam',
        'createdAt': DateTime(2024).toIso8601String(),
        'updatedAt': DateTime(2024).toIso8601String(),
      };

      final decoded = pieceFromJson(json);

      expect(decoded.collaborators, [
        const Collaborator(
          uid: 'student-1',
          name: 'Sam',
          email: 'sam@example.com',
        ),
        const Collaborator(uid: 'student-2', name: 'Alex'),
      ]);
    },
  );
}
