import 'package:pieces/src/domain/collaborator.dart';
import 'package:pieces/src/domain/piece.dart';

/// Serialization between [Piece] and the JSON shape persisted by
/// `LocalPieceRepository`. Kept as pure functions so they're unit-testable
/// independent of storage.
///
/// `collaborators` is the canonical field. `studentId`/`studentName` are
/// DUAL-WRITTEN alongside it (the first collaborator, or absent) for one
/// release, so anything still reading the legacy shape doesn't lose data.
Map<String, dynamic> pieceToJson(Piece piece) => <String, dynamic>{
  'id': piece.id,
  'title': piece.title,
  'basePdfChecksum': piece.basePdfChecksum,
  'basePdfPath': piece.basePdfPath,
  'teacherId': piece.teacherId,
  'teacherName': piece.teacherName,
  'collaborators': [
    for (final collaborator in piece.collaborators)
      <String, dynamic>{
        'uid': collaborator.uid,
        'name': collaborator.name,
        'email': collaborator.email,
      },
  ],
  // Legacy shim — see the doc above.
  'studentId': piece.studentId,
  'studentName': piece.studentName,
  'createdAt': piece.createdAt.toIso8601String(),
  'updatedAt': piece.updatedAt.toIso8601String(),
};

/// Reverses [pieceToJson]. Reads `collaborators` first; falls back to the
/// legacy `studentId`/`studentName` pair (decoded as a single collaborator,
/// AC-10) for records persisted before the migration; falls back to an
/// empty list when neither is present. `teacherName` is read leniently
/// (absent -> `null`) so records persisted before it existed keep decoding
/// cleanly rather than throwing.
Piece pieceFromJson(Map<String, dynamic> json) => Piece(
  id: json['id'] as String,
  title: json['title'] as String,
  basePdfChecksum: json['basePdfChecksum'] as String,
  basePdfPath: json['basePdfPath'] as String,
  teacherId: json['teacherId'] as String,
  teacherName: json['teacherName'] as String?,
  collaborators: _collaboratorsFromJson(json),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

List<Collaborator> _collaboratorsFromJson(Map<String, dynamic> json) {
  final raw = json['collaborators'] as List<dynamic>?;
  if (raw != null) {
    return [
      for (final entry in raw)
        _collaboratorFromJson(entry as Map<String, dynamic>),
    ];
  }
  final studentId = json['studentId'] as String?;
  if (studentId == null) return const <Collaborator>[];
  return [Collaborator(uid: studentId, name: json['studentName'] as String?)];
}

Collaborator _collaboratorFromJson(Map<String, dynamic> json) => Collaborator(
  uid: json['uid'] as String,
  name: json['name'] as String?,
  email: json['email'] as String?,
);
