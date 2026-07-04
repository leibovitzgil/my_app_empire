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
      createdAt: DateTime(2024, 1, 2, 3),
      updatedAt: DateTime(2024, 1, 3, 4),
    );

    final roundTripped = pieceFromJson(pieceToJson(piece));

    expect(roundTripped, piece);
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
}
