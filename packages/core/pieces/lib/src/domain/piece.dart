import 'package:equatable/equatable.dart';
import 'package:pieces/src/domain/collaborator.dart';

/// A single piece of sheet music shared between a teacher (its owner) and
/// zero or more collaborators.
class Piece extends Equatable {
  /// Creates a [Piece].
  ///
  /// [collaborators] is the current, canonical list. [studentId]/
  /// [studentName] are back-compat construction sugar for pre-migration
  /// call sites: when [collaborators] isn't given, a non-null [studentId]
  /// seeds a single-entry collaborators list — mirroring the on-disk
  /// migration in `piece_mappers.dart`. Prefer [collaborators] in new code.
  Piece({
    required this.id,
    required this.title,
    required this.basePdfChecksum,
    required this.basePdfPath,
    required this.teacherId,
    required this.createdAt,
    required this.updatedAt,
    this.teacherName,
    List<Collaborator>? collaborators,
    String? studentId,
    String? studentName,
  }) : collaborators =
           collaborators ??
           (studentId == null
               ? const <Collaborator>[]
               : <Collaborator>[
                   Collaborator(uid: studentId, name: studentName),
                 ]);

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

  /// The teacher's display name, if known at the time this piece was
  /// imported/registered. Nullable: older/imported pieces predating this
  /// field, or a teacher whose identity had no resolvable display name at
  /// import time, won't have one — UI falls back to an initials-from-id
  /// placeholder in that case.
  final String? teacherName;

  /// Every collaborator currently granted access to this piece, beyond its
  /// owner. Order is insertion order (earliest-invited first).
  final List<Collaborator> collaborators;

  /// When this piece was first imported.
  final DateTime createdAt;

  /// When this piece (or its metadata) was last modified.
  final DateTime updatedAt;

  /// Back-compat read-only view of the first collaborator's uid. Not
  /// `@Deprecated`, to avoid cascading lint at every read call site — prefer
  /// [collaborators]/[isCollaborator] in new code.
  String? get studentId =>
      collaborators.isEmpty ? null : collaborators.first.uid;

  /// Back-compat read-only view of the first collaborator's name. See
  /// [studentId].
  String? get studentName =>
      collaborators.isEmpty ? null : collaborators.first.name;

  /// The uids of every current collaborator.
  List<String> get collaboratorIds => [
    for (final collaborator in collaborators) collaborator.uid,
  ];

  /// The uids of every participant on this piece: the owner plus every
  /// collaborator.
  List<String> get participantIds => [teacherId, ...collaboratorIds];

  /// The number of current collaborators. The shared input to
  /// [CollaboratorLimits]'s cap check.
  int get collaboratorCount => collaborators.length;

  /// Whether [userId] is one of this piece's current collaborators (not
  /// counting the owner — see [isParticipant]).
  bool isCollaborator(String userId) =>
      collaborators.any((collaborator) => collaborator.uid == userId);

  /// Whether [userId] is a participant on this piece at all: its owner or
  /// one of its collaborators.
  bool isParticipant(String userId) =>
      userId == teacherId || isCollaborator(userId);

  /// Returns a copy with the given fields replaced.
  ///
  /// [studentId]/[studentName] are back-compat sugar (see the constructor
  /// doc): when given and [collaborators] isn't, they replace/backfill the
  /// *first* collaborator slot, matching the pre-migration single-student
  /// semantics. Prefer passing [collaborators] directly in new code.
  Piece copyWith({
    String? title,
    String? teacherName,
    List<Collaborator>? collaborators,
    String? studentId,
    String? studentName,
    DateTime? updatedAt,
  }) {
    return Piece(
      id: id,
      title: title ?? this.title,
      basePdfChecksum: basePdfChecksum,
      basePdfPath: basePdfPath,
      teacherId: teacherId,
      teacherName: teacherName ?? this.teacherName,
      collaborators:
          collaborators ?? _mergeLegacyStudent(studentId, studentName),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Backs [copyWith]'s legacy `studentId`/`studentName` sugar: replaces (or
  /// backfills, if there wasn't one yet) the first collaborator slot only,
  /// leaving any other collaborators untouched.
  List<Collaborator> _mergeLegacyStudent(
    String? studentId,
    String? studentName,
  ) {
    if (studentId == null && studentName == null) return collaborators;
    final resolvedId = studentId ?? this.studentId;
    if (resolvedId == null) return collaborators;
    final resolvedName = studentName ?? this.studentName;
    final updated = Collaborator(uid: resolvedId, name: resolvedName);
    if (collaborators.isEmpty) return [updated];
    return [updated, ...collaborators.skip(1)];
  }

  @override
  List<Object?> get props => [
    id,
    title,
    basePdfChecksum,
    basePdfPath,
    teacherId,
    teacherName,
    collaborators,
    createdAt,
    updatedAt,
  ];
}

/// The maximum number of [Collaborator]s a [Piece] may have, gated by
/// monetization tier — the single canonical cap predicate. Both the
/// email-invite service and the deep-link invite service call this (never
/// maintain their own divergent count), so free-vs-paid enforcement can't
/// drift between the two invite paths. Semantics are explicitly per-piece:
/// [Piece.collaboratorCount], not a library-wide total.
class CollaboratorLimits {
  const CollaboratorLimits._();

  /// The maximum number of collaborators a free-tier piece may have.
  static const int freeTier = 1;

  /// The maximum number of collaborators a paid-tier piece may have.
  static const int paid = 8;

  /// The cap that applies given [isPro].
  static int capFor(bool isPro) => isPro ? paid : freeTier;

  /// Whether [piece] is already at (or over) its cap for [isPro].
  static bool isAtCap(Piece piece, bool isPro) =>
      piece.collaboratorCount >= capFor(isPro);
}
