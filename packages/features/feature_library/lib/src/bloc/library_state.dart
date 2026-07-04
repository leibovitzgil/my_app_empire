part of 'library_bloc.dart';

/// High-level phase of the Home / Piece List screen.
enum LibraryStatus { loading, ready, failure }

/// Immutable state for [LibraryBloc].
final class LibraryState extends Equatable {
  const LibraryState._({
    required this.currentUserId,
    required this.currentRole,
    this.status = LibraryStatus.loading,
    this.pieces = const [],
    this.viewedPieceIds = const {},
    this.error,
  });

  /// The initial state before [LibraryStarted] resolves.
  const LibraryState.initial({
    required String currentUserId,
    required PieceRole currentRole,
  }) : this._(currentUserId: currentUserId, currentRole: currentRole);

  /// The signed-in participant's id.
  final String currentUserId;

  /// Whether the signed-in participant is a teacher or a student — resolved
  /// by the caller, not derived from [pieces] (a brand-new teacher with zero
  /// pieces still needs the teacher layout, e.g. to see "Import piece").
  final PieceRole currentRole;

  /// The current phase.
  final LibraryStatus status;

  /// Every piece [PieceRepository.watchPieces] currently reports for this
  /// user (as teacher or student).
  final List<Piece> pieces;

  /// Ids of pieces opened this session, via [PieceViewed]. Session-local
  /// only: see [isUnread].
  final Set<String> viewedPieceIds;

  /// The most recent failure, if any.
  final String? error;

  /// Whether [piece] should show an "unread activity" indicator.
  ///
  /// GAP: there is no persisted per-user "last viewed" watermark anywhere in
  /// this factory yet (no repository tracks it), so this is a placeholder
  /// heuristic: a piece counts as unread if it has been modified since it was
  /// imported (`updatedAt` after `createdAt`) and hasn't been opened this
  /// session. It resets on every app launch and can't distinguish "a new
  /// stroke since I last looked" from "a new stroke ever" across sessions —
  /// a real implementation needs a persisted `(userId, pieceId) ->
  /// lastViewedAt` store, e.g. alongside `review_sync`'s local-storage
  /// bookkeeping.
  bool isUnread(Piece piece) =>
      piece.updatedAt.isAfter(piece.createdAt) &&
      !viewedPieceIds.contains(piece.id);

  /// Teacher variant: this teacher's own pieces, grouped by paired student id
  /// (`null` for pieces awaiting a student, e.g. just imported).
  Map<String?, List<Piece>> get piecesByStudent {
    final grouped = <String?, List<Piece>>{};
    for (final piece in pieces.where((p) => p.teacherId == currentUserId)) {
      (grouped[piece.studentId] ??= <Piece>[]).add(piece);
    }
    return grouped;
  }

  /// Student variant: the pieces a teacher has shared with this student.
  List<Piece> get sharedWithMe =>
      pieces.where((p) => p.studentId == currentUserId).toList();

  /// This teacher's pieces that have no paired student yet — candidates for
  /// the "Invite student" action.
  List<Piece> get unpairedPieces => piecesByStudent[null] ?? const [];

  /// Returns a copy with the given fields replaced.
  LibraryState copyWith({
    LibraryStatus? status,
    List<Piece>? pieces,
    Set<String>? viewedPieceIds,
    String? error,
    bool clearError = false,
  }) {
    return LibraryState._(
      currentUserId: currentUserId,
      currentRole: currentRole,
      status: status ?? this.status,
      pieces: pieces ?? this.pieces,
      viewedPieceIds: viewedPieceIds ?? this.viewedPieceIds,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    currentUserId,
    currentRole,
    status,
    pieces,
    viewedPieceIds,
    error,
  ];
}
