part of 'library_bloc.dart';

/// High-level phase of the Home / Sheet Library screen.
enum LibraryStatus { loading, ready, failure }

/// Which subset of pieces the Stage gallery currently shows.
enum LibraryFilter {
  /// Every piece the user can see (owned + shared) — the default.
  all,

  /// Only pieces this user owns.
  mine,

  /// Only pieces shared with this user (they're a collaborator, not owner).
  shared,

  /// Favorited pieces. A placeholder today — see [LibraryState.favoritePieces].
  favorites,
}

/// How [LibraryState.visiblePieces] (and the gallery's shelves/grid) order
/// their pieces.
enum LibrarySort {
  /// Most recently modified first — the default.
  recentlyUpdated,

  /// Most recently imported first.
  recentlyAdded,

  /// Alphabetical by title.
  title,
}

/// Immutable state for [LibraryBloc].
final class LibraryState extends Equatable {
  const LibraryState._({
    required this.currentUserId,
    this.status = LibraryStatus.loading,
    this.pieces = const [],
    this.lastOpenedAt = const {},
    this.error,
    this.filter = LibraryFilter.all,
    this.query = '',
    this.sort = LibrarySort.recentlyUpdated,
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

  /// Per-piece "last opened" watermarks for this user (`pieceId` → when they
  /// last opened it), sourced from [PieceRepository.watchReads] and advanced
  /// by [PieceViewed]. A missing entry means never opened. Backs [isUnread].
  final Map<String, DateTime> lastOpenedAt;

  /// The most recent failure, if any.
  final String? error;

  /// Which shelf/grid the Stage gallery currently shows.
  final LibraryFilter filter;

  /// The current search query, exactly as typed (untrimmed).
  final String query;

  /// How [visiblePieces] (and the shelves/grid) currently order pieces.
  final LibrarySort sort;

  /// Whether [piece] should show an "unread activity" indicator.
  ///
  /// Unread only when the piece is **shared with** this user (they're a
  /// collaborator, not the owner — an owner's own edits never dot their own
  /// sheet) and its content has changed since they last opened it:
  /// [Piece.updatedAt] is after their [lastOpenedAt] watermark. A missing
  /// watermark means never opened, so a freshly-shared piece reads as unread.
  /// The watermark is persisted per user via [PieceRepository.markOpened] /
  /// [PieceRepository.watchReads] (M3.7), replacing the old session-local
  /// `updatedAt > createdAt` heuristic.
  bool isUnread(Piece piece) {
    if (!piece.isCollaborator(currentUserId)) return false;
    final openedAt = lastOpenedAt[piece.id];
    return openedAt == null || piece.updatedAt.isAfter(openedAt);
  }

  /// The sheets this user owns (imported themselves) — the "My sheets" shelf.
  List<Piece> get myPieces =>
      pieces.where((p) => p.ownerId == currentUserId).toList();

  /// The sheets others have shared with this user (they're a collaborator on
  /// them, not the owner) — the "Shared with me" shelf.
  List<Piece> get sharedWithMe =>
      pieces.where((p) => p.isCollaborator(currentUserId)).toList();

  /// How many of [sharedWithMe] are currently unread — drives the "Shared
  /// with me" chip's dot and that shelf's "N new" pill.
  int get unreadSharedCount => sharedWithMe.where(isUnread).length;

  /// [myPieces], narrowed by [query] and ordered by [sort].
  List<Piece> get visibleMyPieces => _view(myPieces);

  /// [sharedWithMe], narrowed by [query] and ordered by [sort].
  List<Piece> get visibleSharedPieces => _view(sharedWithMe);

  /// Favorited pieces. Always empty — favoriting isn't implemented yet (see
  /// the Favorites chip's "coming soon" empty state).
  List<Piece> get favoritePieces => const [];

  /// The pieces the current [filter] resolves to, narrowed by [query] and
  /// ordered by [sort] (except [LibraryFilter.favorites], which is always
  /// empty).
  List<Piece> get visiblePieces => switch (filter) {
    LibraryFilter.all => _view(pieces),
    LibraryFilter.mine => visibleMyPieces,
    LibraryFilter.shared => visibleSharedPieces,
    LibraryFilter.favorites => favoritePieces,
  };

  /// Search results across the *whole* library, independent of the active
  /// [filter], narrowed by [query] and ordered by [sort]. Search is global —
  /// searching while a narrower filter (e.g. "My sheets", or the always-empty
  /// "Favorites") is active still finds every matching sheet. Only meaningful
  /// when [query] is non-empty.
  List<Piece> get searchResults => _view(pieces);

  List<Piece> _view(List<Piece> src) => _sort(_search(src));

  List<Piece> _search(List<Piece> src) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return src;
    return src
        .where((p) => p.title.toLowerCase().contains(normalized))
        .toList();
  }

  // Sorts on an explicit comparator (rather than relying on `List.sort`'s
  // own stability guarantees) so ties always break the same way regardless
  // of the underlying sort algorithm — deterministic output for identical
  // input, which both the UI and tests can rely on.
  List<Piece> _sort(List<Piece> src) {
    final sorted = [...src];
    switch (sort) {
      case LibrarySort.recentlyUpdated:
        sorted.sort((a, b) {
          final byDate = b.updatedAt.compareTo(a.updatedAt);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
      case LibrarySort.recentlyAdded:
        sorted.sort((a, b) {
          final byDate = b.createdAt.compareTo(a.createdAt);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
      case LibrarySort.title:
        sorted.sort((a, b) {
          final byTitle = a.title.toLowerCase().compareTo(
            b.title.toLowerCase(),
          );
          return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
        });
    }
    return sorted;
  }

  /// Returns a copy with the given fields replaced.
  LibraryState copyWith({
    LibraryStatus? status,
    List<Piece>? pieces,
    Map<String, DateTime>? lastOpenedAt,
    String? error,
    bool clearError = false,
    LibraryFilter? filter,
    String? query,
    LibrarySort? sort,
  }) {
    return LibraryState._(
      currentUserId: currentUserId,
      status: status ?? this.status,
      pieces: pieces ?? this.pieces,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      error: clearError ? null : (error ?? this.error),
      filter: filter ?? this.filter,
      query: query ?? this.query,
      sort: sort ?? this.sort,
    );
  }

  @override
  List<Object?> get props => [
    currentUserId,
    status,
    pieces,
    lastOpenedAt,
    error,
    filter,
    query,
    sort,
  ];
}
