import 'package:duet/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Piece', () {
    test('supports value equality', () {
      final now = DateTime(2024);
      final piece = Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'abc123',
        basePdfPath: '/pieces/p1.pdf',
        ownerId: 'owner-1',
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
          ownerId: 'owner-1',
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
        ownerId: 'owner-1',
        createdAt: now,
        updatedAt: now,
      );

      final renamed = piece.copyWith(title: 'Reverie');

      expect(renamed.title, 'Reverie');
      expect(renamed.id, piece.id);
      expect(renamed.ownerId, piece.ownerId);
    });

    test('collaborators defaults to empty, and names default to null', () {
      final now = DateTime(2024);
      final piece = Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'abc123',
        basePdfPath: '/pieces/p1.pdf',
        ownerId: 'owner-1',
        createdAt: now,
        updatedAt: now,
      );

      expect(piece.collaborators, isEmpty);
      expect(piece.ownerName, isNull);
      expect(piece.collaboratorCount, 0);
      expect(piece.collaboratorIds, isEmpty);
      expect(piece.participantIds, ['owner-1']);
    });

    test('collaborators participate in value equality', () {
      final now = DateTime(2024);
      Piece build(List<Collaborator> collaborators) => Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'abc123',
        basePdfPath: '/pieces/p1.pdf',
        ownerId: 'owner-1',
        ownerName: 'Jane',
        collaborators: collaborators,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        build(const [Collaborator(uid: 'collaborator-1', name: 'Sam')]),
        build(const [Collaborator(uid: 'collaborator-1', name: 'Sam')]),
      );
      expect(
        build(const [Collaborator(uid: 'collaborator-1', name: 'Sam')]),
        isNot(
          build(const [
            Collaborator(uid: 'collaborator-1', name: 'Someone'),
          ]),
        ),
      );
    });

    test('copyWith preserves an existing name when not given a new one', () {
      final now = DateTime(2024);
      final piece = Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'abc123',
        basePdfPath: '/pieces/p1.pdf',
        ownerId: 'owner-1',
        ownerName: 'Jane',
        createdAt: now,
        updatedAt: now,
      );

      final renamed = piece.copyWith(title: 'Reverie');

      expect(renamed.ownerName, 'Jane');
    });

    test('copyWith replaces collaborators when given', () {
      final now = DateTime(2024);
      final piece = Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'abc123',
        basePdfPath: '/pieces/p1.pdf',
        ownerId: 'owner-1',
        ownerName: 'Jane',
        createdAt: now,
        updatedAt: now,
      );

      final updated = piece.copyWith(
        collaborators: const [
          Collaborator(uid: 'collaborator-1', name: 'Sam'),
        ],
        ownerName: 'Jane Doe',
      );

      expect(updated.collaborators, [
        const Collaborator(uid: 'collaborator-1', name: 'Sam'),
      ]);
      expect(updated.collaboratorIds, ['collaborator-1']);
      expect(updated.ownerName, 'Jane Doe');
      expect(updated.isCollaborator('collaborator-1'), isTrue);
      expect(updated.isParticipant('collaborator-1'), isTrue);
      expect(updated.isParticipant('owner-1'), isTrue);
      expect(updated.isParticipant('someone-else'), isFalse);
    });

    test('multiple collaborators: ids/participants/count', () {
      final now = DateTime(2024);
      final piece = Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'abc123',
        basePdfPath: '/pieces/p1.pdf',
        ownerId: 'owner-1',
        collaborators: const [
          Collaborator(uid: 'collaborator-1'),
          Collaborator(uid: 'collaborator-2'),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(piece.collaboratorCount, 2);
      expect(piece.collaboratorIds, ['collaborator-1', 'collaborator-2']);
      expect(piece.participantIds, [
        'owner-1',
        'collaborator-1',
        'collaborator-2',
      ]);
      expect(piece.isCollaborator('collaborator-2'), isTrue);
      expect(piece.isCollaborator('owner-1'), isFalse);
      expect(piece.isParticipant('owner-1'), isTrue);
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
      ownerId: 'owner-1',
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
