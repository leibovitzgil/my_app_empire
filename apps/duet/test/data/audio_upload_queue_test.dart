import 'package:core_utils/core_utils.dart';
import 'package:duet/data/audio_upload_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioUploadQueue', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      storage = LocalStorageService(await SharedPreferences.getInstance());
    });

    AudioUploadTask task(String assetId, {String pieceId = 'p1'}) =>
        AudioUploadTask(
          pieceId: pieceId,
          assetId: assetId,
          localPath: '/tmp/$assetId.m4a',
        );

    test('enqueue adds a task; it is idempotent by assetId', () async {
      final queue = AudioUploadQueue(storage: storage);
      addTearDown(queue.close);

      await queue.enqueue(task('a'));
      await queue.enqueue(task('a')); // duplicate
      await queue.enqueue(task('b'));

      expect(queue.pendingCount, 2);
    });

    test('drain uploads each task and clears the queue on success', () async {
      final queue = AudioUploadQueue(storage: storage);
      addTearDown(queue.close);
      await queue.enqueue(task('a'));
      await queue.enqueue(task('b'));

      final uploaded = <String>[];
      await queue.drain((t) async {
        uploaded.add(t.assetId);
        return const Success<void>(null);
      });

      expect(uploaded, ['a', 'b']);
      expect(queue.pendingCount, 0);
    });

    test('a failed upload is retried (kept, attempt bumped)', () async {
      final queue = AudioUploadQueue(storage: storage);
      addTearDown(queue.close);
      await queue.enqueue(task('a'));

      await queue.drain(
        (t) async => ResultFailure<void>(StateError('offline')),
      );
      expect(queue.pendingCount, 1); // still queued

      // A later drain (now online) clears it.
      var calls = 0;
      await queue.drain((t) async {
        calls++;
        return const Success<void>(null);
      });
      expect(calls, 1);
      expect(queue.pendingCount, 0);
    });

    test('a task is dropped after maxAttempts failed drains', () async {
      final queue = AudioUploadQueue(storage: storage, maxAttempts: 2);
      addTearDown(queue.close);
      await queue.enqueue(task('a'));

      Future<Result<void>> fail(AudioUploadTask t) async =>
          ResultFailure<void>(StateError('offline'));

      await queue.drain(fail); // attempts: 1
      expect(queue.pendingCount, 1);
      await queue.drain(fail); // attempts: 2 -> reaches cap, dropped
      expect(queue.pendingCount, 0);
    });

    test(
      'queued uploads survive a restart (fresh instance, same store)',
      () async {
        final queue = AudioUploadQueue(storage: storage);
        await queue.enqueue(task('a', pieceId: 'piece-9'));
        await queue.close();

        // A fresh queue over the same storage still sees the pending upload.
        final restarted = AudioUploadQueue(storage: storage);
        addTearDown(restarted.close);
        expect(restarted.pendingCount, 1);

        AudioUploadTask? drained;
        await restarted.drain((t) async {
          drained = t;
          return const Success<void>(null);
        });
        expect(drained?.assetId, 'a');
        expect(drained?.pieceId, 'piece-9');
      },
    );

    test('pending stream emits the count on change', () async {
      final queue = AudioUploadQueue(storage: storage);
      addTearDown(queue.close);

      final counts = <int>[];
      final sub = queue.pending.listen(counts.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await queue.enqueue(task('a'));
      await pumpEventQueue();

      expect(counts, [0, 1]); // initial 0, then 1 after enqueue
    });
  });
}
