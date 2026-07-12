import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duet/data/firestore_annotation_mappers.dart';
import 'package:duet/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('firestore annotation mappers', () {
    const stroke = InkStroke(
      id: 's1',
      authorId: 'author-1',
      pageIndex: 2,
      colorId: 'red',
      points: [InkPoint(x: 0.1, y: 0.2), InkPoint(x: 0.3, y: 0.4)],
    );

    // A local (not UTC) DateTime: Firestore `Timestamp.toDate()` returns a
    // local DateTime, which is what the app produces, so the round-trip is
    // value-equal (see firestore_piece_mappers_test.dart).
    final note = AudioNote(
      id: 'n1',
      authorId: 'author-1',
      audioAssetId: 'asset-1',
      pageIndex: 1,
      durationMs: 5000,
      region: const Region(
        pageIndex: 1,
        left: 0.1,
        top: 0.2,
        width: 0.3,
        height: 0.4,
      ),
      createdAt: DateTime(2024, 1, 2, 9, 30),
    );

    test('inkStroke round-trips through its Firestore map', () {
      expect(inkStrokeFromFirestore(inkStrokeToFirestore(stroke)), stroke);
    });

    test('layerToFirestore carries role, rev and an updatedAt Timestamp', () {
      final data = layerToFirestore(
        const InkLayer(
          ownerId: 'author-1',
          role: PieceRole.collaborator,
          strokes: [stroke],
        ),
        rev: 3,
        updatedAt: DateTime(2024, 5, 6, 7),
      );

      expect(data['role'], 'collaborator');
      expect(data['rev'], 3);
      expect(
        (data['updatedAt'] as Timestamp).toDate(),
        DateTime(2024, 5, 6, 7),
      );
    });

    test('layerFromFirestore takes ownerId from the document id', () {
      final data = layerToFirestore(
        const InkLayer(
          ownerId: 'ignored-field',
          role: PieceRole.owner,
          strokes: [stroke],
        ),
        rev: 1,
        updatedAt: DateTime(2024),
      );

      final layer = layerFromFirestore('author-9', data);
      expect(layer.ownerId, 'author-9');
      expect(layer.role, PieceRole.owner);
      expect(layer.strokes.single, stroke);
    });

    test('a layer document without strokes reads as an empty layer', () {
      expect(strokesFromLayer(<String, dynamic>{}), isEmpty);
      final layer = layerFromFirestore('author-1', <String, dynamic>{
        'role': 'owner',
      });
      expect(layer.strokes, isEmpty);
    });

    test('audioNote round-trips, storing createdAt as a Timestamp', () {
      final data = audioNoteToFirestore(note);
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['deletedAt'], isNull);
      expect(audioNoteFromFirestore('n1', data), note);
    });

    test('audioNoteFromFirestore falls back to the document id', () {
      final data = audioNoteToFirestore(note)..remove('id');
      expect(audioNoteFromFirestore('doc-id', data).id, 'doc-id');
    });

    test('isAudioNoteTombstoned only when deletedAt is set', () {
      expect(isAudioNoteTombstoned(audioNoteToFirestore(note)), isFalse);
      expect(isAudioNoteTombstoned(<String, dynamic>{}), isFalse);
      expect(
        isAudioNoteTombstoned(<String, dynamic>{
          'deletedAt': Timestamp.fromDate(DateTime(2024)),
        }),
        isTrue,
      );
    });
  });
}
