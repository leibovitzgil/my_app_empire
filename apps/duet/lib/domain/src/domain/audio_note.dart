import 'package:equatable/equatable.dart';

/// A fractional rectangle (0.0-1.0 of a page's width/height) locating an
/// [AudioNote] on the score, so it stays aligned across devices and zoom
/// levels.
class Region extends Equatable {
  /// Creates a [Region].
  const Region({
    required this.pageIndex,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// The zero-based page index this region is on.
  final int pageIndex;

  /// The fractional left edge (0.0-1.0).
  final double left;

  /// The fractional top edge (0.0-1.0).
  final double top;

  /// The fractional width (0.0-1.0).
  final double width;

  /// The fractional height (0.0-1.0).
  final double height;

  @override
  List<Object?> get props => [pageIndex, left, top, width, height];
}

/// A short recorded note pinned to a [region] on a piece's score.
class AudioNote extends Equatable {
  /// Creates an [AudioNote].
  const AudioNote({
    required this.id,
    required this.authorId,
    required this.audioAssetId,
    required this.pageIndex,
    required this.durationMs,
    required this.region,
    required this.createdAt,
    this.deletedAt,
  });

  /// The stable identifier for this note.
  final String id;

  /// The id of the participant who recorded this note.
  final String authorId;

  /// The id of the underlying audio asset, resolved via
  /// `AudioAssetStore.pathFor`.
  final String audioAssetId;

  /// The zero-based page index this note was recorded on.
  final int pageIndex;

  /// The recording's duration, in milliseconds.
  final int durationMs;

  /// Where on the page this note is pinned.
  final Region region;

  /// When this note was recorded.
  final DateTime createdAt;

  /// When this note was soft-deleted (M4.4), or `null` for a live note.
  /// Deletes tombstone rather than physically removing the document so they
  /// converge across offline peers instead of resurrecting; `watch` filters
  /// tombstoned notes out, so blocs and UI never see a non-null [deletedAt].
  final DateTime? deletedAt;

  /// Whether this note is a tombstone (soft-deleted) rather than live.
  bool get isTombstoned => deletedAt != null;

  /// Returns a copy of this note with the given fields replaced. Cannot clear
  /// [deletedAt] back to `null` (tombstones are terminal — a delete never
  /// un-deletes), which the tombstone convergence relies on.
  AudioNote copyWith({
    String? id,
    String? authorId,
    String? audioAssetId,
    int? pageIndex,
    int? durationMs,
    Region? region,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) => AudioNote(
    id: id ?? this.id,
    authorId: authorId ?? this.authorId,
    audioAssetId: audioAssetId ?? this.audioAssetId,
    pageIndex: pageIndex ?? this.pageIndex,
    durationMs: durationMs ?? this.durationMs,
    region: region ?? this.region,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  @override
  List<Object?> get props => [
    id,
    authorId,
    audioAssetId,
    pageIndex,
    durationMs,
    region,
    createdAt,
    deletedAt,
  ];
}
