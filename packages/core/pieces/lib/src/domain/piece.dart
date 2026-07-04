import 'package:equatable/equatable.dart';

/// A single piece of sheet music shared between a teacher and (optionally)
/// a student.
class Piece extends Equatable {
  /// Creates a [Piece].
  const Piece({
    required this.id,
    required this.title,
    required this.basePdfChecksum,
    required this.basePdfPath,
    required this.teacherId,
    required this.createdAt,
    required this.updatedAt,
    this.studentId,
    this.teacherName,
    this.studentName,
  });

  /// The stable identifier for this piece.
  final String id;

  /// The display title, e.g. "Clair de Lune".
  final String title;

  /// A content checksum of the original PDF, used to detect drift between
  /// copies and to key cached renders.
  final String basePdfChecksum;

  /// The on-device path to the original (unannotated) PDF.
  final String basePdfPath;

  /// The id of the teacher who owns this piece.
  final String teacherId;

  /// The id of the student paired on this piece, if one has joined.
  final String? studentId;

  /// The teacher's display name, if known at the time this piece was
  /// imported/registered. Nullable: older/imported pieces predating this
  /// field, or a teacher whose identity had no resolvable display name at
  /// import time, won't have one — UI falls back to an initials-from-id
  /// placeholder in that case.
  final String? teacherName;

  /// The paired student's display name, if known at the time they paired.
  /// Nullable for the same reasons as [teacherName], plus the simple case of
  /// no student having paired yet.
  final String? studentName;

  /// When this piece was first imported.
  final DateTime createdAt;

  /// When this piece (or its metadata) was last modified.
  final DateTime updatedAt;

  /// Returns a copy with the given fields replaced.
  Piece copyWith({
    String? title,
    String? studentId,
    String? teacherName,
    String? studentName,
    DateTime? updatedAt,
  }) {
    return Piece(
      id: id,
      title: title ?? this.title,
      basePdfChecksum: basePdfChecksum,
      basePdfPath: basePdfPath,
      teacherId: teacherId,
      studentId: studentId ?? this.studentId,
      teacherName: teacherName ?? this.teacherName,
      studentName: studentName ?? this.studentName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    basePdfChecksum,
    basePdfPath,
    teacherId,
    studentId,
    teacherName,
    studentName,
    createdAt,
    updatedAt,
  ];
}
