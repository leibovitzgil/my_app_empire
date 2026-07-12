import 'package:duet/domain/domain.dart';
import 'package:duet/domain/src/data/annotation_mappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inkStrokeToJson / inkStrokeFromJson round-trip', () {
    const stroke = InkStroke(
      id: 's1',
      authorId: 'owner-1',
      pageIndex: 2,
      colorId: 'blue',
      points: [InkPoint(x: 0.1, y: 0.2), InkPoint(x: 0.3, y: 0.4)],
    );

    expect(inkStrokeFromJson(inkStrokeToJson(stroke)), stroke);
  });

  test('inkLayerToJson / inkLayerFromJson round-trip', () {
    const layer = InkLayer(
      ownerId: 'collaborator-1',
      role: PieceRole.collaborator,
      strokes: [
        InkStroke(
          id: 's1',
          authorId: 'collaborator-1',
          pageIndex: 0,
          colorId: 'green',
          points: [InkPoint(x: 0, y: 0)],
        ),
      ],
    );

    expect(inkLayerFromJson(inkLayerToJson(layer)), layer);
  });

  test('audioNoteToJson / audioNoteFromJson round-trip', () {
    final note = AudioNote(
      id: 'n1',
      authorId: 'owner-1',
      audioAssetId: 'asset-1',
      pageIndex: 1,
      durationMs: 4200,
      region: const Region(
        pageIndex: 1,
        left: 0.1,
        top: 0.2,
        width: 0.3,
        height: 0.15,
      ),
      createdAt: DateTime(2024, 5, 6),
    );

    expect(audioNoteFromJson(audioNoteToJson(note)), note);
  });

  test('pieceAnnotationsToJson / pieceAnnotationsFromJson round-trip', () {
    final annotations = PieceAnnotations(
      pieceId: 'piece-1',
      layers: const [
        InkLayer(
          ownerId: 'owner-1',
          role: PieceRole.owner,
          strokes: [
            InkStroke(
              id: 's1',
              authorId: 'owner-1',
              pageIndex: 0,
              colorId: 'red',
              points: [InkPoint(x: 0, y: 0)],
            ),
          ],
        ),
      ],
      audioNotes: [
        AudioNote(
          id: 'n1',
          authorId: 'owner-1',
          audioAssetId: 'asset-1',
          pageIndex: 0,
          durationMs: 1000,
          region: const Region(
            pageIndex: 0,
            left: 0,
            top: 0,
            width: 0.1,
            height: 0.1,
          ),
          createdAt: DateTime(2024),
        ),
      ],
    );

    expect(
      pieceAnnotationsFromJson(pieceAnnotationsToJson(annotations)),
      annotations,
    );
  });
}
