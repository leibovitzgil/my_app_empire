import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pieces/pieces.dart';

/// Serialization between the annotation domain types and their Firestore
/// document shapes (per `docs/duet_cloud_schema.md`), the cloud counterpart to
/// `pieces`' `annotation_mappers.dart`.
///
/// Two deliberate differences from the local JSON shape:
///
///  - `AudioNote.createdAt` is a Firestore `Timestamp` (the local mapper uses
///    an ISO-8601 string), matching `firestore_piece_mappers.dart`.
///  - Ink strokes live inside a per-author *layer document* (`layers/{uid}`)
///    that also carries a monotonic `rev` and an `updatedAt` `Timestamp` — used
///    to order concurrent writes and drive future digests (M5.4); an audio-note
///    document carries a `deletedAt` tombstone (null until M4.4 flips it),
///    which the reader filters out.

Map<String, dynamic> _inkPointToFirestore(InkPoint point) => <String, dynamic>{
  'x': point.x,
  'y': point.y,
};

InkPoint _inkPointFromFirestore(Map<String, dynamic> json) => InkPoint(
  x: (json['x'] as num).toDouble(),
  y: (json['y'] as num).toDouble(),
);

/// Serializes [stroke] to its Firestore map (nested inside a layer document).
Map<String, dynamic> inkStrokeToFirestore(InkStroke stroke) =>
    <String, dynamic>{
      'id': stroke.id,
      'authorId': stroke.authorId,
      'pageIndex': stroke.pageIndex,
      'colorId': stroke.colorId,
      'points': stroke.points.map(_inkPointToFirestore).toList(),
    };

/// Reverses [inkStrokeToFirestore].
InkStroke inkStrokeFromFirestore(Map<String, dynamic> json) => InkStroke(
  id: json['id'] as String,
  authorId: json['authorId'] as String,
  pageIndex: json['pageIndex'] as int,
  colorId: json['colorId'] as String,
  points: (json['points'] as List<dynamic>)
      .map((e) => _inkPointFromFirestore(e as Map<String, dynamic>))
      .toList(),
);

/// The ink strokes stored in a `layers/{uid}` document (empty for a legacy or
/// freshly-created doc without the field).
List<InkStroke> strokesFromLayer(Map<String, dynamic> data) =>
    (data['strokes'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => inkStrokeFromFirestore(e as Map<String, dynamic>))
        .toList();

/// Serializes [layer] to a `layers/{uid}` document. [rev] is the new monotonic
/// revision and [updatedAt] the write time — together they let peers order
/// concurrent writes and drive future annotation digests.
Map<String, dynamic> layerToFirestore(
  InkLayer layer, {
  required int rev,
  required DateTime updatedAt,
}) => <String, dynamic>{
  'ownerId': layer.ownerId,
  'role': layer.role.name,
  'strokes': layer.strokes.map(inkStrokeToFirestore).toList(),
  'rev': rev,
  'updatedAt': Timestamp.fromDate(updatedAt),
};

/// Reverses [layerToFirestore]. [uid] is the document id — the author's uid,
/// the authoritative owner identity the rules enforce (`request.auth.uid ==
/// uid`). A document missing `role` reads as a collaborator; the reader
/// re-derives the authoritative role from the piece's owner anyway.
InkLayer layerFromFirestore(String uid, Map<String, dynamic> data) => InkLayer(
  ownerId: uid,
  role: _roleFromName(data['role'] as String?),
  strokes: strokesFromLayer(data),
);

PieceRole _roleFromName(String? name) => PieceRole.values.firstWhere(
  (role) => role.name == name,
  orElse: () => PieceRole.collaborator,
);

Map<String, dynamic> _regionToFirestore(Region region) => <String, dynamic>{
  'pageIndex': region.pageIndex,
  'left': region.left,
  'top': region.top,
  'width': region.width,
  'height': region.height,
};

Region _regionFromFirestore(Map<String, dynamic> json) => Region(
  pageIndex: json['pageIndex'] as int,
  left: (json['left'] as num).toDouble(),
  top: (json['top'] as num).toDouble(),
  width: (json['width'] as num).toDouble(),
  height: (json['height'] as num).toDouble(),
);

/// Serializes [note] to a `notes/{noteId}` document. `deletedAt` starts null;
/// M4.4 flips it to a `Timestamp` tombstone instead of hard-deleting, so a
/// delete converges across offline peers rather than resurrecting.
Map<String, dynamic> audioNoteToFirestore(AudioNote note) => <String, dynamic>{
  'id': note.id,
  'authorId': note.authorId,
  'audioAssetId': note.audioAssetId,
  'pageIndex': note.pageIndex,
  'durationMs': note.durationMs,
  'region': _regionToFirestore(note.region),
  'createdAt': Timestamp.fromDate(note.createdAt),
  'deletedAt': null,
};

/// Reverses [audioNoteToFirestore]. [id] is the document id; the `deletedAt`
/// tombstone is ignored here (the repository filters tombstoned notes out
/// before mapping — see [isAudioNoteTombstoned]).
AudioNote audioNoteFromFirestore(String id, Map<String, dynamic> data) =>
    AudioNote(
      id: data['id'] as String? ?? id,
      authorId: data['authorId'] as String,
      audioAssetId: data['audioAssetId'] as String,
      pageIndex: data['pageIndex'] as int,
      durationMs: data['durationMs'] as int,
      region: _regionFromFirestore(data['region'] as Map<String, dynamic>),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );

/// Whether [data] is a tombstoned (soft-deleted) audio-note document (M4.4).
bool isAudioNoteTombstoned(Map<String, dynamic> data) =>
    data['deletedAt'] != null;
