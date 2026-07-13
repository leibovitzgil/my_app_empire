// Unit-tests the pure sync-state derivation and the stream combination that
// back `FirestorePieceSyncMonitor` (M4.1), driven by fake signal streams so
// no Firestore/emulator is needed — the real snapshot metadata plumbing is
// exercised end-to-end by the emulator E2E (M4.5).
import 'dart:async';

import 'package:duet/data/firestore_piece_sync_monitor.dart';
import 'package:duet/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flushes pending microtask-delivered stream events.
Future<void> _tick() => Future<void>.delayed(Duration.zero);

const _serverClean = SyncSignal(isFromCache: false, hasPendingWrites: false);
const _serverPending = SyncSignal(isFromCache: false, hasPendingWrites: true);
const _cacheClean = SyncSignal(isFromCache: true, hasPendingWrites: false);
const _cachePending = SyncSignal(isFromCache: true, hasPendingWrites: true);

void main() {
  group('pieceSyncStateFrom', () {
    test('online with nothing pending -> synced', () {
      expect(
        pieceSyncStateFrom(pending: false, offline: false),
        PieceSyncState.synced,
      );
    });

    test('any pending write -> syncing, even when offline', () {
      expect(
        pieceSyncStateFrom(pending: true, offline: false),
        PieceSyncState.syncing,
      );
      expect(
        pieceSyncStateFrom(pending: true, offline: true),
        PieceSyncState.syncing,
      );
    });

    test('offline with nothing pending -> offline', () {
      expect(
        pieceSyncStateFrom(pending: false, offline: true),
        PieceSyncState.offline,
      );
    });
  });

  group('combinePieceSyncSignals', () {
    late StreamController<SyncSignal> layers;
    late StreamController<SyncSignal> notes;
    late StreamController<int> audioDepth;
    late List<PieceSyncState> emitted;
    late StreamSubscription<PieceSyncState> subscription;

    setUp(() {
      layers = StreamController<SyncSignal>();
      notes = StreamController<SyncSignal>();
      audioDepth = StreamController<int>();
      emitted = <PieceSyncState>[];
      subscription = combinePieceSyncSignals(
        layers: layers.stream,
        notes: notes.stream,
        audioDepth: audioDepth.stream,
      ).listen(emitted.add);
    });

    tearDown(() async {
      await subscription.cancel();
      await layers.close();
      await notes.close();
      await audioDepth.close();
    });

    test(
      'waits for both collection signals before the first emission',
      () async {
        layers.add(_serverClean);
        audioDepth.add(0);
        await _tick();
        expect(emitted, isEmpty);

        notes.add(_serverClean);
        await _tick();
        expect(emitted, [PieceSyncState.synced]);
      },
    );

    test('all-server, nothing pending, empty queue -> synced', () async {
      layers.add(_serverClean);
      notes.add(_serverClean);
      audioDepth.add(0);
      await _tick();
      expect(emitted, [PieceSyncState.synced]);
    });

    test('a pending layer write -> syncing', () async {
      layers.add(_serverPending);
      notes.add(_serverClean);
      await _tick();
      expect(emitted, [PieceSyncState.syncing]);
    });

    test('a pending note write -> syncing', () async {
      layers.add(_serverClean);
      notes.add(_serverPending);
      await _tick();
      expect(emitted, [PieceSyncState.syncing]);
    });

    test(
      'a queued audio upload -> syncing even when Firestore is clean',
      () async {
        // The queue reports its depth on subscribe (before the Firestore
        // snapshots land), so seed it first — a non-empty queue means syncing
        // even though both collections are server-clean.
        audioDepth.add(2);
        layers.add(_serverClean);
        notes.add(_serverClean);
        await _tick();
        expect(emitted, [PieceSyncState.syncing]);
      },
    );

    test('cache-only read with nothing pending -> offline', () async {
      layers.add(_cacheClean);
      notes.add(_cacheClean);
      audioDepth.add(0);
      await _tick();
      expect(emitted, [PieceSyncState.offline]);
    });

    test('pending outranks offline (cache + pending -> syncing)', () async {
      layers.add(_cachePending);
      notes.add(_cacheClean);
      await _tick();
      expect(emitted, [PieceSyncState.syncing]);
    });

    test('a draining audio queue clears syncing back to synced', () async {
      // A pending upload while Firestore is otherwise clean -> syncing…
      audioDepth.add(1);
      layers.add(_serverClean);
      notes.add(_serverClean);
      await _tick();
      // …then the queue drains to empty -> synced.
      audioDepth.add(0);
      await _tick();
      expect(emitted, [PieceSyncState.syncing, PieceSyncState.synced]);
    });

    test('a collection stream error degrades that source to offline', () async {
      // A snapshot stream can error (permission-denied on a sign-out race, a
      // transient unavailable). It must not escape as an uncaught zone error —
      // the source folds to an unconfirmed cache read.
      layers.addError(StateError('permission-denied'));
      notes.add(_serverClean);
      audioDepth.add(0);
      await _tick();
      expect(emitted, [PieceSyncState.offline]);
    });

    test('a stream error stays syncing when writes are pending', () async {
      notes.add(_serverPending);
      layers.addError(StateError('unavailable'));
      await _tick();
      expect(emitted, [PieceSyncState.syncing]);
    });

    test('de-duplicates consecutive equal states', () async {
      layers.add(_serverClean);
      notes.add(_serverClean);
      await _tick();
      // Re-emitting the same metadata (a no-op snapshot) must not re-notify.
      layers.add(_serverClean);
      notes.add(_serverClean);
      await _tick();
      expect(emitted, [PieceSyncState.synced]);
    });

    test(
      'the reader narrative: synced -> offline -> syncing -> synced',
      () async {
        // Online and settled.
        layers.add(_serverClean);
        notes.add(_serverClean);
        audioDepth.add(0);
        await _tick();

        // Go offline: Firestore now serves both collections from cache, nothing
        // pending.
        layers.add(_cacheClean);
        notes.add(_cacheClean);
        await _tick();

        // Draw an offline stroke: the caller's own layer gains a pending write.
        layers.add(_cachePending);
        await _tick();

        // Reconnect and flush. The notes collection (no pending write) confirms
        // to the server first — a pure cache->server metadata flip that leaves
        // the verdict at syncing while the layer is still pending, so it emits
        // nothing new — then the layer write flushes and we land on synced.
        notes.add(_serverClean);
        layers.add(_serverClean);
        await _tick();

        expect(emitted, [
          PieceSyncState.synced,
          PieceSyncState.offline,
          PieceSyncState.syncing,
          PieceSyncState.synced,
        ]);
      },
    );
  });
}
