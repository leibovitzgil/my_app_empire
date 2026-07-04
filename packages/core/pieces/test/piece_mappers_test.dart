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
      studentId: 'student-1',
      teacherName: 'Jane Doe',
      studentName: 'Sam Smith',
      createdAt: DateTime(2024, 1, 2, 3),
      updatedAt: DateTime(2024, 1, 3, 4),
    );

    final roundTripped = pieceFromJson(pieceToJson(piece));

    expect(roundTripped, piece);
    expect(roundTripped.teacherName, 'Jane Doe');
    expect(roundTripped.studentName, 'Sam Smith');
  });

  test('pieceFromJson handles a null studentId', () {
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
        // Deliberately no `teacherName`/`studentName` keys at all, mirroring
        // a record persisted before those fields existed.
      };

      final decoded = pieceFromJson(json);

      expect(decoded.id, 'p1');
      expect(decoded.studentId, 'student-1');
      expect(decoded.teacherName, isNull);
      expect(decoded.studentName, isNull);
    },
  );
}
