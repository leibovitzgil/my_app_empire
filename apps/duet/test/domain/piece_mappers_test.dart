import 'package:duet/domain/domain.dart';
import 'package:duet/domain/src/data/piece_mappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pieceToJson / pieceFromJson round-trip', () {
    final piece = Piece(
      id: 'p1',
      title: 'Clair de Lune',
      basePdfChecksum: 'abc123',
      basePdfPath: '/pieces/p1.pdf',
      ownerId: 'owner-1',
      collaborators: const [
        Collaborator(uid: 'collaborator-1', name: 'Sam Smith'),
      ],
      ownerName: 'Jane Doe',
      createdAt: DateTime(2024, 1, 2, 3),
      updatedAt: DateTime(2024, 1, 3, 4),
    );

    final roundTripped = pieceFromJson(pieceToJson(piece));

    expect(roundTripped, piece);
    expect(roundTripped.ownerName, 'Jane Doe');
    expect(roundTripped.collaborators, piece.collaborators);
  });

  test('pieceToJson writes ownerId/ownerName and collaborators', () {
    final piece = Piece(
      id: 'p1',
      title: 'Clair de Lune',
      basePdfChecksum: 'abc123',
      basePdfPath: '/pieces/p1.pdf',
      ownerId: 'owner-1',
      ownerName: 'Jane Doe',
      collaborators: const [
        Collaborator(uid: 'collaborator-1', name: 'Sam Smith'),
      ],
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    final json = pieceToJson(piece);

    expect(json['ownerId'], 'owner-1');
    expect(json['ownerName'], 'Jane Doe');
    expect(json['collaborators'], [
      {'uid': 'collaborator-1', 'name': 'Sam Smith', 'email': null},
    ]);
  });

  test('pieceFromJson handles no collaborators', () {
    final piece = Piece(
      id: 'p1',
      title: 'Solo piece',
      basePdfChecksum: 'abc123',
      basePdfPath: '/pieces/p1.pdf',
      ownerId: 'owner-1',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    final roundTripped = pieceFromJson(pieceToJson(piece));

    expect(roundTripped.collaborators, isEmpty);
    expect(roundTripped, piece);
  });

  test(
    'pieceFromJson decodes a JSON record without ownerName as null rather '
    'than throwing',
    () {
      final json = <String, dynamic>{
        'id': 'p1',
        'title': 'Persisted before names existed',
        'basePdfChecksum': 'abc123',
        'basePdfPath': '/pieces/p1.pdf',
        'ownerId': 'owner-1',
        'createdAt': DateTime(2024).toIso8601String(),
        'updatedAt': DateTime(2024).toIso8601String(),
        // Deliberately no `ownerName`/`collaborators` keys at all, mirroring
        // a record persisted before those fields existed.
      };

      final decoded = pieceFromJson(json);

      expect(decoded.id, 'p1');
      expect(decoded.ownerName, isNull);
      expect(decoded.collaborators, isEmpty);
    },
  );

  test('pieceFromJson decodes multiple collaborators', () {
    final json = <String, dynamic>{
      'id': 'p1',
      'title': 'Multi-collaborator piece',
      'basePdfChecksum': 'abc123',
      'basePdfPath': '/pieces/p1.pdf',
      'ownerId': 'owner-1',
      'collaborators': [
        {'uid': 'collaborator-1', 'name': 'Sam', 'email': 'sam@example.com'},
        {'uid': 'collaborator-2', 'name': 'Alex', 'email': null},
      ],
      'createdAt': DateTime(2024).toIso8601String(),
      'updatedAt': DateTime(2024).toIso8601String(),
    };

    final decoded = pieceFromJson(json);

    expect(decoded.collaborators, [
      const Collaborator(
        uid: 'collaborator-1',
        name: 'Sam',
        email: 'sam@example.com',
      ),
      const Collaborator(uid: 'collaborator-2', name: 'Alex'),
    ]);
  });
}
