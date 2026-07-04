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
  });
}
