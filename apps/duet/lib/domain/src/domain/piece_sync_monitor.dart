/// The reader's live sync signal for a single piece, derived from real
/// persistence state rather than a session-local flag.
///
/// - [synced]: everything this device holds for the piece is on the server.
/// - [syncing]: local edits — ink/notes still un-acked by Firestore, or a
///   queued audio asset (M3.5) — are in flight (or will be the moment the
///   connection returns).
/// - [offline]: the server is unreachable, so the reader is showing the local
///   cache; edits are saved on-device and sync when connectivity returns.
///
/// The app-glue layer (`DuetScorePage`) maps this onto the presentational
/// `ScoreSyncStatus` the `score` feature renders, so the feature never depends
/// on Firebase (G3).
enum PieceSyncState {
  /// Fully up to date with the server.
  synced,

  /// Local edits are still being pushed (or are queued for the next
  /// connection).
  syncing,

  /// The server is unreachable; the reader is on the local cache.
  offline,
}

/// Watches the live [PieceSyncState] of a piece's annotations.
///
/// A domain seam — like `AnnotationRepository` — so the reader's sync badge
/// reflects true persistence state without the `score` feature reaching for
/// Firebase. The default composition binds `LocalPieceSyncMonitor` (always
/// [PieceSyncState.synced]: the on-device store has no remote to fall behind);
/// the `useFirebase` composition binds the Firestore-backed monitor.
// ignore: one_member_abstracts
abstract class PieceSyncMonitor {
  /// Emits [pieceId]'s sync state on subscribe and on every change, until the
  /// subscription is cancelled. Single-subscription — one reader is open per
  /// piece at a time.
  Stream<PieceSyncState> watch(String pieceId);
}
