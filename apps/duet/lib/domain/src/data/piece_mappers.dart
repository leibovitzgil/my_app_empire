import 'package:duet/domain/src/domain/collaborator.dart';
import 'package:duet/domain/src/domain/piece.dart';

/// Serialization between [Piece] and the JSON shape persisted by
/// `LocalPieceRepository`. Kept as pure functions so they're unit-testable
/// independent of storage.
Map<String, dynamic> pieceToJson(Piece piece) => <String, dynamic>{
  'id': piece.id,
  'title': piece.title,
  'basePdfChecksum': piece.basePdfChecksum,
  'basePdfPath': piece.basePdfPath,
  'ownerId': piece.ownerId,
  'ownerName': piece.ownerName,
  'collaborators': [
    for (final collaborator in piece.collaborators)
      <String, dynamic>{
        'uid': collaborator.uid,
        'name': collaborator.name,
        'email': collaborator.email,
      },
  ],
  'createdAt': piece.createdAt.toIso8601String(),
  'updatedAt': piece.updatedAt.toIso8601String(),
};

/// Reverses [pieceToJson]. `ownerName` is read leniently (absent -> `null`).
Piece pieceFromJson(Map<String, dynamic> json) => Piece(
  id: json['id'] as String,
  title: json['title'] as String,
  basePdfChecksum: json['basePdfChecksum'] as String,
  basePdfPath: json['basePdfPath'] as String,
  ownerId: json['ownerId'] as String,
  ownerName: json['ownerName'] as String?,
  collaborators: _collaboratorsFromJson(json),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

List<Collaborator> _collaboratorsFromJson(Map<String, dynamic> json) {
  final raw = json['collaborators'] as List<dynamic>?;
  if (raw == null) return const <Collaborator>[];
  return [
    for (final entry in raw)
      _collaboratorFromJson(entry as Map<String, dynamic>),
  ];
}

Collaborator _collaboratorFromJson(Map<String, dynamic> json) => Collaborator(
  uid: json['uid'] as String,
  name: json['name'] as String?,
  email: json['email'] as String?,
);
