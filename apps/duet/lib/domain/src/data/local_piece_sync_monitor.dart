import 'package:duet/domain/src/domain/piece_sync_monitor.dart';

/// The default [PieceSyncMonitor]: the on-device repositories persist
/// synchronously to local storage, so a piece is always
/// [PieceSyncState.synced] — there is no remote to fall behind.
///
/// Keeps the headless gate Firebase-free (G2) while still giving the reader a
/// real monitor to subscribe to; the Firestore-backed monitor takes over under
/// `useFirebase: true`.
class LocalPieceSyncMonitor implements PieceSyncMonitor {
  /// Creates a [LocalPieceSyncMonitor].
  const LocalPieceSyncMonitor();

  @override
  Stream<PieceSyncState> watch(String pieceId) =>
      Stream<PieceSyncState>.value(PieceSyncState.synced);
}
