import 'dart:io';
import 'dart:typed_data';

import 'package:core_utils/core_utils.dart';
import 'package:duet/data/audio_object_store.dart';
import 'package:duet/data/audio_upload_queue.dart';
import 'package:duet/data/cloud_audio_asset_store.dart';
import 'package:duet/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake [AudioObjectStore] standing in for Cloud Storage: records
/// uploads/deletes and materializes a download from [remoteContent].
class _FakeObjectStore implements AudioObjectStore {
  final List<String> uploaded = <String>[];
  final List<String> deleted = <String>[];

  /// assetId -> bytes available to download (a collaborator's object).
  final Map<String, String> remoteContent = <String, String>{};
  bool uploadFails = false;

  @override
  Future<Result<void>> upload({
    required String pieceId,
    required String assetId,
    required String localPath,
  }) async {
    if (uploadFails) return const ResultFailure<void>(SocketException('down'));
    uploaded.add(assetId);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> download({
    required String pieceId,
    required String assetId,
    required String destPath,
  }) async {
    final content = remoteContent[assetId];
    if (content == null) {
      return ResultFailure<void>(StateError('no remote object'));
    }
    File(destPath).writeAsStringSync(content);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> delete({
    required String pieceId,
    required String assetId,
  }) async {
    deleted.add(assetId);
    return const Success<void>(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudAudioAssetStore', () {
    late Directory tempDir;
    late File source;
    late LocalStorageService storage;
    late AudioUploadQueue queue;
    late _FakeObjectStore objectStore;
    late CloudAudioAssetStore store;

    Future<Directory> documentsDirectory() async => tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cloud_audio');
      source = File('${tempDir.path}/recording.m4a')
        ..writeAsStringSync('sound');
      SharedPreferences.setMockInitialValues(<String, Object>{});
      storage = LocalStorageService(await SharedPreferences.getInstance());
      queue = AudioUploadQueue(storage: storage);
      objectStore = _FakeObjectStore();
      store = CloudAudioAssetStore(
        objectStore: objectStore,
        uploadQueue: queue,
        documentsDirectory: documentsDirectory,
      );
    });

    tearDown(() async {
      await queue.close();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('put caches the file locally and enqueues an upload', () async {
      objectStore.uploadFails = true; // keep it queued so we can observe it
      final id = (await store.put(source.path, pieceId: 'p1')).orThrow();
      await pumpEventQueue();

      // Cached on-device (plays back offline)...
      final path = (await store.pathFor(id, pieceId: 'p1')).orThrow();
      expect(File(path).readAsStringSync(), 'sound');
      // ...and still queued (the best-effort upload failed).
      expect(queue.pendingCount, 1);
    });

    test('put fails with "Recording too large" over the byte cap — '
        'nothing cached, nothing enqueued', () async {
      // The cap mirrors the Storage rules' 5 MB audio limit (M8.3): an
      // over-cap file must never sit in the upload queue only to be
      // bounced by the rules.
      final oversized = File('${tempDir.path}/oversized.m4a')
        ..writeAsBytesSync(Uint8List(maxAudioNoteBytes));

      final result = await store.put(oversized.path, pieceId: 'p1');
      await pumpEventQueue();

      expect(result, isA<ResultFailure<String>>());
      final error = (result as ResultFailure<String>).error;
      expect(error, isA<AudioNoteTooLargeException>());
      expect('$error', contains('Recording too large'));
      expect(queue.pendingCount, 0);
      expect(objectStore.uploaded, isEmpty);
    });

    test('put best-effort-uploads when online, draining the queue', () async {
      final id = (await store.put(source.path, pieceId: 'p1')).orThrow();
      await pumpEventQueue();

      expect(objectStore.uploaded, [id]);
      expect(queue.pendingCount, 0);
    });

    test('an offline recording uploads on a later drain (reconnect)', () async {
      objectStore.uploadFails = true;
      final id = (await store.put(source.path, pieceId: 'p1')).orThrow();
      await pumpEventQueue();
      expect(queue.pendingCount, 1);

      // Reconnect: the queue drains and the note reaches Storage.
      objectStore.uploadFails = false;
      await store.drainUploads();

      expect(objectStore.uploaded, [id]);
      expect(queue.pendingCount, 0);
    });

    test('pathFor returns the cached copy without downloading', () async {
      final id = (await store.put(source.path, pieceId: 'p1')).orThrow();

      final path = (await store.pathFor(id, pieceId: 'p1')).orThrow();

      expect(File(path).existsSync(), isTrue);
      expect(objectStore.remoteContent, isEmpty); // never consulted
    });

    test(
      "pathFor downloads a collaborator's note on a cache miss",
      () async {
        objectStore.remoteContent['asset-x'] = 'their-recording';

        final path = (await store.pathFor(
          'asset-x',
          pieceId: 'p1',
        )).orThrow();

        expect(File(path).readAsStringSync(), 'their-recording');
      },
    );

    test('pathFor fails when the asset is neither cached nor remote', () async {
      final result = await store.pathFor('ghost', pieceId: 'p1');
      expect(result, isA<ResultFailure<String>>());
    });

    test('delete removes the remote object and the local copy', () async {
      objectStore.uploadFails = true;
      final id = (await store.put(source.path, pieceId: 'p1')).orThrow();
      await pumpEventQueue();

      (await store.delete(id, pieceId: 'p1')).orThrow();

      expect(objectStore.deleted, [id]);
      expect(
        await store.pathFor(id, pieceId: 'p1'),
        isA<ResultFailure<String>>(),
      );
    });
  });
}
