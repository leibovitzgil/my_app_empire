part of 'library_bloc.dart';

sealed class LibraryEvent extends Equatable {
  const LibraryEvent();

  @override
  List<Object?> get props => [];
}

/// Subscribes to [PieceRepository.watchPieces]. Safe to re-add (e.g. from a
/// retry action): re-subscribes, cancelling any previous subscription first.
final class LibraryStarted extends LibraryEvent {
  const LibraryStarted();
}

/// Internal: the repository's stream emitted a new snapshot.
final class LibraryPiecesUpdated extends LibraryEvent {
  const LibraryPiecesUpdated(this.pieces);

  final List<Piece> pieces;

  @override
  List<Object?> get props => [pieces];
}

/// Internal: the repository's stream emitted an error.
final class LibraryFailed extends LibraryEvent {
  const LibraryFailed(this.error);

  final String error;

  @override
  List<Object?> get props => [error];
}

/// Marks [pieceId] as viewed this session, clearing its unread indicator.
///
/// Session-local only — see `LibraryState.isUnread` for why (no persisted
/// last-viewed watermark exists yet).
final class PieceViewed extends LibraryEvent {
  const PieceViewed(this.pieceId);

  final String pieceId;

  @override
  List<Object?> get props => [pieceId];
}

/// Changes which shelf/grid the Stage gallery shows.
final class LibraryFilterChanged extends LibraryEvent {
  const LibraryFilterChanged(this.filter);

  final LibraryFilter filter;

  @override
  List<Object?> get props => [filter];
}

/// Updates the current search query, e.g. as the user types.
final class LibrarySearchChanged extends LibraryEvent {
  const LibrarySearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Changes how the gallery orders pieces.
final class LibrarySortChanged extends LibraryEvent {
  const LibrarySortChanged(this.sort);

  final LibrarySort sort;

  @override
  List<Object?> get props => [sort];
}
