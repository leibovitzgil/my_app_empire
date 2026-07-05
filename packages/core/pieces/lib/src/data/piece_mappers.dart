import 'package:pieces/src/domain/piece.dart';

/// Serialization between [Piece] and the JSON shape persisted by
/// `LocalPieceRepository`. Kept as pure functions so they're unit-testable
/// independent of storage.
Map<String, dynamic> pieceToJson(Piece piece) => <String, dynamic>{
  'id': piece.id,
  'title': piece.title,
  'basePdfChecksum': piece.basePdfChecksum,
  'basePdfPath': piece.basePdfPath,
  'teacherId': piece.teacherId,
  'studentId': piece.studentId,
  'teacherName': piece.teacherName,
  'studentName': piece.studentName,
  'createdAt': piece.createdAt.toIso8601String(),
  'updatedAt': piece.updatedAt.toIso8601String(),
};

/// Reverses [pieceToJson]. `teacherName`/`studentName` are read leniently
/// (absent -> `null`) so records persisted before those fields existed keep
/// decoding cleanly rather than throwing.
Piece pieceFromJson(Map<String, dynamic> json) => Piece(
  id: json['id'] as String,
  title: json['title'] as String,
  basePdfChecksum: json['basePdfChecksum'] as String,
  basePdfPath: json['basePdfPath'] as String,
  teacherId: json['teacherId'] as String,
  studentId: json['studentId'] as String?,
  teacherName: json['teacherName'] as String?,
  studentName: json['studentName'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);
