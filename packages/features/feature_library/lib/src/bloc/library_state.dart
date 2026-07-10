part of 'library_bloc.dart';

/// High-level phase of the Home / Sheet Library screen.
enum LibraryStatus { loading, ready, failure }

/// Immutable state for [LibraryBloc].
final class LibraryState extends Equatable {
  const LibraryState._({
    required this.currentUserId,
    this.status = LibraryStatus.loading,
    this.pieces = const [],
    this.viewedPieceIds = const {},
    this.error,
  });

  /// The initial state before [LibraryStarted] resolves.
  const LibraryState.initial({required String currentUserId})
    : this._(currentUserId: currentUserId);

  /// The signed-in user's id.
  final String currentUserId;

  /// The current phase.
  final LibraryStatus status;

  /// Every piece [PieceRepository.watchPieces] currently reports for this
  /// user (as owner or collaborator), already sorted most-recently-updated
  /// first by the repository.
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

  /// The sheets this user owns (imported themselves) — the "My sheets" tab.
  List<Piece> get myPieces =>
      pieces.where((p) => p.ownerId == currentUserId).toList();

  /// The sheets others have shared with this user (they're a collaborator on
  /// them, not the owner) — the "Shared with me" tab.
  List<Piece> get sharedWithMe =>
      pieces.where((p) => p.isCollaborator(currentUserId)).toList();

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
      status: status ?? this.status,
      pieces: pieces ?? this.pieces,
      viewedPieceIds: viewedPieceIds ?? this.viewedPieceIds,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    currentUserId,
    status,
    pieces,
    viewedPieceIds,
    error,
  ];
}
