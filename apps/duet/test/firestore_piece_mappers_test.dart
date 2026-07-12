import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duet/data/firestore_piece_mappers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pieces/pieces.dart';

void main() {
  group('firestore piece mappers', () {
    final piece = Piece(
      id: 'p1',
      title: 'Clair de Lune',
      basePdfChecksum: 'sha-abc',
      basePdfPath: '/local/p1.pdf',
      ownerId: 'owner-1',
      ownerName: 'Olivia',
      collaborators: const [
        Collaborator(uid: 'c1', name: 'Ravi', email: 'ravi@example.com'),
      ],
      // Local (not UTC) DateTimes: Firestore `Timestamp.toDate()` returns a
      // local DateTime, which is what the repos produce (`DateTime.now()`), so
      // the round-trip is value-equal. A UTC DateTime would be the same instant
      // but compare unequal (different `isUtc`).
      createdAt: DateTime(2024, 1, 1, 9),
      updatedAt: DateTime(2024, 1, 2, 10),
    );

    test('pieceToFirestore materializes participantIds (owner + collabs)', () {
      final data = pieceToFirestore(piece);
      expect(data['participantIds'], ['owner-1', 'c1']);
    });

    test('pieceToFirestore writes createdAt/updatedAt as Timestamps', () {
      final data = pieceToFirestore(piece);
      expect(data['createdAt'], isA<Timestamp>());
      expect((data['updatedAt'] as Timestamp).toDate(), piece.updatedAt);
    });

    test('pieceToFirestore does not store the device-local basePdfPath', () {
      expect(pieceToFirestore(piece).containsKey('basePdfPath'), isFalse);
    });

    test(
      'round-trips through Firestore shape with an injected basePdfPath',
      () {
        final restored = pieceFromFirestore(
          piece.id,
          pieceToFirestore(piece),
          basePdfPath: '/resolved/p1.pdf',
        );
        expect(restored.title, piece.title);
        expect(restored.basePdfChecksum, piece.basePdfChecksum);
        expect(restored.basePdfPath, '/resolved/p1.pdf');
        expect(restored.ownerId, piece.ownerId);
        expect(restored.ownerName, piece.ownerName);
        expect(restored.collaborators, piece.collaborators);
        expect(restored.createdAt, piece.createdAt);
        expect(restored.updatedAt, piece.updatedAt);
      },
    );

    test('a doc without collaborators reads as an empty list', () {
      final data = pieceToFirestore(piece)..remove('collaborators');
      final restored = pieceFromFirestore(piece.id, data, basePdfPath: '');
      expect(restored.collaborators, isEmpty);
    });
  });
}
