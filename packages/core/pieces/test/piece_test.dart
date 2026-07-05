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

    test('teacherName/studentName default to null', () {
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

      expect(piece.teacherName, isNull);
      expect(piece.studentName, isNull);
    });

    test('teacherName/studentName participate in value equality', () {
      final now = DateTime(2024);
      Piece build({String? teacherName, String? studentName}) => Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'abc123',
        basePdfPath: '/pieces/p1.pdf',
        teacherId: 'teacher-1',
        studentId: 'student-1',
        teacherName: teacherName,
        studentName: studentName,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        build(teacherName: 'Jane', studentName: 'Sam'),
        build(teacherName: 'Jane', studentName: 'Sam'),
      );
      expect(
        build(teacherName: 'Jane', studentName: 'Sam'),
        isNot(build(teacherName: 'Someone else', studentName: 'Sam')),
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

    test('copyWith replaces teacherName/studentName when given', () {
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
        studentId: 'student-1',
        studentName: 'Sam',
        teacherName: 'Jane Doe',
      );

      expect(updated.studentId, 'student-1');
      expect(updated.studentName, 'Sam');
      expect(updated.teacherName, 'Jane Doe');
    });
  });
}
