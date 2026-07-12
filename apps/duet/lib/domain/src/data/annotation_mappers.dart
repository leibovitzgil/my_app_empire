import 'package:duet/domain/src/domain/annotation_repository.dart';
import 'package:duet/domain/src/domain/audio_note.dart';
import 'package:duet/domain/src/domain/ink_layer.dart';
import 'package:duet/domain/src/domain/ink_stroke.dart';

/// Serialization between the annotation domain types and the JSON shape
/// persisted by `LocalAnnotationRepository`. Kept as pure functions so
/// they're unit-testable independent of storage.
Map<String, dynamic> inkPointToJson(InkPoint point) => <String, dynamic>{
  'x': point.x,
  'y': point.y,
};

/// Reverses [inkPointToJson].
InkPoint inkPointFromJson(Map<String, dynamic> json) => InkPoint(
  x: (json['x'] as num).toDouble(),
  y: (json['y'] as num).toDouble(),
);

/// Serializes [stroke] to JSON.
Map<String, dynamic> inkStrokeToJson(InkStroke stroke) => <String, dynamic>{
  'id': stroke.id,
  'authorId': stroke.authorId,
  'pageIndex': stroke.pageIndex,
  'colorId': stroke.colorId,
  'points': stroke.points.map(inkPointToJson).toList(),
};

/// Reverses [inkStrokeToJson].
InkStroke inkStrokeFromJson(Map<String, dynamic> json) => InkStroke(
  id: json['id'] as String,
  authorId: json['authorId'] as String,
  pageIndex: json['pageIndex'] as int,
  colorId: json['colorId'] as String,
  points: (json['points'] as List<dynamic>)
      .map((e) => inkPointFromJson(e as Map<String, dynamic>))
      .toList(),
);

/// Serializes [layer] to JSON.
Map<String, dynamic> inkLayerToJson(InkLayer layer) => <String, dynamic>{
  'ownerId': layer.ownerId,
  'role': layer.role.name,
  'strokes': layer.strokes.map(inkStrokeToJson).toList(),
};

/// Reverses [inkLayerToJson].
InkLayer inkLayerFromJson(Map<String, dynamic> json) => InkLayer(
  ownerId: json['ownerId'] as String,
  role: _roleFromName(json['role'] as String?),
  strokes: (json['strokes'] as List<dynamic>)
      .map((e) => inkStrokeFromJson(e as Map<String, dynamic>))
      .toList(),
);

PieceRole _roleFromName(String? name) => PieceRole.values.firstWhere(
  (role) => role.name == name,
  orElse: () => PieceRole.collaborator,
);

/// Serializes [region] to JSON.
Map<String, dynamic> regionToJson(Region region) => <String, dynamic>{
  'pageIndex': region.pageIndex,
  'left': region.left,
  'top': region.top,
  'width': region.width,
  'height': region.height,
};

/// Reverses [regionToJson].
Region regionFromJson(Map<String, dynamic> json) => Region(
  pageIndex: json['pageIndex'] as int,
  left: (json['left'] as num).toDouble(),
  top: (json['top'] as num).toDouble(),
  width: (json['width'] as num).toDouble(),
  height: (json['height'] as num).toDouble(),
);

/// Serializes [note] to JSON.
Map<String, dynamic> audioNoteToJson(AudioNote note) => <String, dynamic>{
  'id': note.id,
  'authorId': note.authorId,
  'audioAssetId': note.audioAssetId,
  'pageIndex': note.pageIndex,
  'durationMs': note.durationMs,
  'region': regionToJson(note.region),
  'createdAt': note.createdAt.toIso8601String(),
};

/// Reverses [audioNoteToJson].
AudioNote audioNoteFromJson(Map<String, dynamic> json) => AudioNote(
  id: json['id'] as String,
  authorId: json['authorId'] as String,
  audioAssetId: json['audioAssetId'] as String,
  pageIndex: json['pageIndex'] as int,
  durationMs: json['durationMs'] as int,
  region: regionFromJson(json['region'] as Map<String, dynamic>),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

/// Serializes [annotations] to JSON.
Map<String, dynamic> pieceAnnotationsToJson(PieceAnnotations annotations) =>
    <String, dynamic>{
      'pieceId': annotations.pieceId,
      'layers': annotations.layers.map(inkLayerToJson).toList(),
      'audioNotes': annotations.audioNotes.map(audioNoteToJson).toList(),
    };

/// Reverses [pieceAnnotationsToJson].
PieceAnnotations pieceAnnotationsFromJson(Map<String, dynamic> json) =>
    PieceAnnotations(
      pieceId: json['pieceId'] as String,
      layers: (json['layers'] as List<dynamic>)
          .map((e) => inkLayerFromJson(e as Map<String, dynamic>))
          .toList(),
      audioNotes: (json['audioNotes'] as List<dynamic>)
          .map((e) => audioNoteFromJson(e as Map<String, dynamic>))
          .toList(),
    );
