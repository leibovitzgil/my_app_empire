import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duet/data/audio_upload_queue.dart';
import 'package:duet/domain/domain.dart';
import 'package:flutter/foundation.dart';

/// One source's sync signal, distilled from a Firestore snapshot's metadata:
/// whether it was served from the local cache (no live server connection) and
/// whether it still carries un-acknowledged local writes.
@immutable
class SyncSignal {
  /// Creates a [SyncSignal].
  const SyncSignal({required this.isFromCache, required this.hasPendingWrites});

  /// True when the snapshot came from the local cache rather than the server —
  /// Firestore's own "no server connection" signal.
  final bool isFromCache;

  /// True while the snapshot still reflects local writes the server hasn't
  /// acknowledged.
  final bool hasPendingWrites;
}

/// The [PieceSyncMonitor] backing the `useFirebase` composition.
///
/// Combines three live signals for a piece and folds them into a
/// [PieceSyncState]:
///   * the `layers` collection's snapshot metadata,
///   * the `notes` collection's snapshot metadata — both via
///     `includeMetadataChanges: true`, so a pending write clearing or a
///     cache→server transition re-emits even when the documents don't change,
///     and
///   * the M3.5 audio upload-queue depth (a queued asset is un-synced local
///     state that Firestore's own metadata can't see).
///
/// Precedence (see [pieceSyncStateFrom]): any un-acked local write ⇒
/// [PieceSyncState.syncing]; otherwise a cache-only read ⇒
/// [PieceSyncState.offline]; otherwise [PieceSyncState.synced]. Bound under
/// `useFirebase: true`; the default composition keeps [LocalPieceSyncMonitor].
class FirestorePieceSyncMonitor implements PieceSyncMonitor {
  /// Creates a [FirestorePieceSyncMonitor]. [uploadQueue] is optional so the
  /// monitor still works where audio uploads aren't wired (its depth is then
  /// treated as always 0).
  FirestorePieceSyncMonitor({
    required FirebaseFirestore firestore,
    AudioUploadQueue? uploadQueue,
  }) : _firestore = firestore,
       _uploadQueue = uploadQueue;

  final FirebaseFirestore _firestore;
  final AudioUploadQueue? _uploadQueue;

  @override
  Stream<PieceSyncState> watch(String pieceId) {
    final pieceRef = _firestore.collection('pieces').doc(pieceId);
    return combinePieceSyncSignals(
      layers: _signals(pieceRef.collection('layers')),
      notes: _signals(pieceRef.collection('notes')),
      audioDepth: _uploadQueue?.pending ?? Stream<int>.value(0),
    );
  }

  Stream<SyncSignal> _signals(Query<Map<String, dynamic>> query) => query
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => SyncSignal(
          isFromCache: snapshot.metadata.isFromCache,
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
        ),
      );
}

/// Folds a piece's live sync signals into a de-duplicated [PieceSyncState]
/// stream.
///
/// Emits only once *both* collection signals have arrived (so the first value
/// reflects true state rather than a half-loaded race), then on every distinct
/// change. The audio-queue [audioDepth] defaults to 0 until it first emits, so
/// a missing/slow queue never blocks the first emission.
@visibleForTesting
Stream<PieceSyncState> combinePieceSyncSignals({
  required Stream<SyncSignal> layers,
  required Stream<SyncSignal> notes,
  required Stream<int> audioDepth,
}) {
  late final StreamController<PieceSyncState> controller;
  final subscriptions = <StreamSubscription<void>>[];

  SyncSignal? latestLayers;
  SyncSignal? latestNotes;
  var latestDepth = 0;
  PieceSyncState? lastEmitted;

  void emit() {
    final currentLayers = latestLayers;
    final currentNotes = latestNotes;
    if (currentLayers == null || currentNotes == null) return;
    final state = pieceSyncStateFrom(
      pending:
          currentLayers.hasPendingWrites ||
          currentNotes.hasPendingWrites ||
          latestDepth > 0,
      offline: currentLayers.isFromCache || currentNotes.isFromCache,
    );
    if (state == lastEmitted) return;
    lastEmitted = state;
    controller.add(state);
  }

  controller = StreamController<PieceSyncState>(
    onListen: () {
      subscriptions.addAll(<StreamSubscription<void>>[
        layers.listen((signal) {
          latestLayers = signal;
          emit();
        }),
        notes.listen((signal) {
          latestNotes = signal;
          emit();
        }),
        audioDepth.listen((depth) {
          latestDepth = depth;
          emit();
        }),
      ]);
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      subscriptions.clear();
    },
  );
  return controller.stream;
}

/// The piece sync-state precedence.
///
/// Un-acked local writes ([pending]) read as [PieceSyncState.syncing] — we're
/// pushing them up, or will be the instant the connection returns. Otherwise a
/// cache-only read ([offline]) reads as [PieceSyncState.offline]. Otherwise
/// [PieceSyncState.synced]. Pending outranks offline so the reader's "going
/// offline flips the badge" demo (no pending writes) reads offline, while an
/// online edit reads syncing→synced without flashing offline.
@visibleForTesting
PieceSyncState pieceSyncStateFrom({
  required bool pending,
  required bool offline,
}) {
  if (pending) return PieceSyncState.syncing;
  if (offline) return PieceSyncState.offline;
  return PieceSyncState.synced;
}
