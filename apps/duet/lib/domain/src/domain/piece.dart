import 'package:duet/domain/src/domain/collaborator.dart';
import 'package:equatable/equatable.dart';

/// A single sheet of music, owned by one user and shared with zero or more
/// collaborators.
class Piece extends Equatable {
  /// Creates a [Piece]. [collaborators] is the canonical list of everyone
  /// granted access beyond the owner; it defaults to empty.
  const Piece({
    required this.id,
    required this.title,
    required this.basePdfChecksum,
    required this.basePdfPath,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.ownerName,
    List<Collaborator>? collaborators,
  }) : collaborators = collaborators ?? const <Collaborator>[];

  /// The stable identifier for this piece.
  final String id;

  /// The display title, e.g. "Clair de Lune".
  final String title;

  /// A content checksum of the original PDF, used to detect drift between
  /// copies and to key cached renders.
  final String basePdfChecksum;

  /// The on-device path to the original (unannotated) PDF.
  final String basePdfPath;

  /// The id of the user who owns this piece (the one who imported it).
  final String ownerId;

  /// The owner's display name, if known at the time this piece was
  /// imported/registered. Nullable: a piece imported by an identity with no
  /// resolvable display name won't have one — UI falls back to an
  /// initials-from-id placeholder in that case.
  final String? ownerName;

  /// Every collaborator currently granted access to this piece, beyond its
  /// owner. Order is insertion order (earliest-invited first).
  final List<Collaborator> collaborators;

  /// When this piece was first imported.
  final DateTime createdAt;

  /// When this piece (or its metadata) was last modified.
  final DateTime updatedAt;

  /// The uids of every current collaborator.
  List<String> get collaboratorIds => [
    for (final collaborator in collaborators) collaborator.uid,
  ];

  /// The uids of every participant on this piece: the owner plus every
  /// collaborator.
  List<String> get participantIds => [ownerId, ...collaboratorIds];

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
      userId == ownerId || isCollaborator(userId);

  /// Returns a copy with the given fields replaced. [basePdfPath] is
  /// overridable so the reader path can be resolved to a cache/download
  /// location at read time (M3.4) without re-fetching the whole entity.
  Piece copyWith({
    String? title,
    String? ownerName,
    String? basePdfPath,
    List<Collaborator>? collaborators,
    DateTime? updatedAt,
  }) {
    return Piece(
      id: id,
      title: title ?? this.title,
      basePdfChecksum: basePdfChecksum,
      basePdfPath: basePdfPath ?? this.basePdfPath,
      ownerId: ownerId,
      ownerName: ownerName ?? this.ownerName,
      collaborators: collaborators ?? this.collaborators,
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
    ownerId,
    ownerName,
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
