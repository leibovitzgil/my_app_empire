import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duet/domain/domain.dart';

/// Serialization between [Piece] and its Firestore document shape (per
/// `docs/duet_cloud_schema.md`), the cloud counterpart to `piece_mappers.dart`.
///
/// Two deliberate differences from the local JSON shape:
///
///  - `createdAt`/`updatedAt` are Firestore `Timestamp`s (the local mapper uses
///    ISO-8601 strings).
///  - `participantIds` is **materialized** — `[ownerId, ...collaborator uids]`,
///    written so a client can query `where('participantIds', arrayContains:
///    uid)`. It's derived from the entity on write and never read back into it
///    (the entity re-derives it via `Piece.participantIds`).
///
/// `basePdfPath` is device-local and deliberately **not** stored (see the
/// schema); [pieceFromFirestore] takes it as a parameter, resolved by the
/// repository from its local binary cache.
Map<String, dynamic> pieceToFirestore(Piece piece) => <String, dynamic>{
  'title': piece.title,
  'ownerId': piece.ownerId,
  'ownerName': piece.ownerName,
  'participantIds': piece.participantIds,
  'collaborators': <Map<String, dynamic>>[
    for (final collaborator in piece.collaborators)
      <String, dynamic>{
        'uid': collaborator.uid,
        'name': collaborator.name,
        'email': collaborator.email,
      },
  ],
  'basePdfChecksum': piece.basePdfChecksum,
  'createdAt': Timestamp.fromDate(piece.createdAt),
  'updatedAt': Timestamp.fromDate(piece.updatedAt),
};

/// Reverses [pieceToFirestore]. [basePdfPath] is supplied by the repository
/// (the doc never carries it); `participantIds` is not read (the entity derives
/// it). Tolerant of a legacy doc missing `collaborators`.
Piece pieceFromFirestore(
  String id,
  Map<String, dynamic> data, {
  required String basePdfPath,
}) => Piece(
  id: id,
  title: data['title'] as String,
  basePdfChecksum: data['basePdfChecksum'] as String,
  basePdfPath: basePdfPath,
  ownerId: data['ownerId'] as String,
  ownerName: data['ownerName'] as String?,
  collaborators: _collaboratorsFrom(data['collaborators']),
  createdAt: (data['createdAt'] as Timestamp).toDate(),
  updatedAt: (data['updatedAt'] as Timestamp).toDate(),
);

List<Collaborator> _collaboratorsFrom(Object? raw) {
  if (raw is! List) return const <Collaborator>[];
  return <Collaborator>[
    for (final entry in raw)
      if (entry is Map)
        Collaborator(
          uid: entry['uid'] as String,
          name: entry['name'] as String?,
          email: entry['email'] as String?,
        ),
  ];
}
