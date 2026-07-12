import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalAudioAssetStore', () {
    late Directory tempDir;
    late LocalAudioAssetStore store;
    late File sourceFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('audio_store_test');
      sourceFile = File('${tempDir.path}/recording.m4a')
        ..writeAsBytesSync([1, 2, 3, 4]);
      store = LocalAudioAssetStore(documentsDirectory: () async => tempDir);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test(
      'put copies the file into managed storage and returns an id',
      () async {
        final result = await store.put(sourceFile.path);

        expect(result, isA<Success<String>>());
        final assetId = (result as Success<String>).value;
        expect(assetId, isNotEmpty);
      },
    );

    test("pathFor resolves a stored asset's on-disk path", () async {
      final putResult = await store.put(sourceFile.path);
      final assetId = (putResult as Success<String>).value;

      final pathResult = await store.pathFor(assetId);

      expect(pathResult, isA<Success<String>>());
      final path = (pathResult as Success<String>).value;
      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsBytesSync(), [1, 2, 3, 4]);
      expect(path, isNot(sourceFile.path));
    });

    test('pathFor fails for an unknown asset id', () async {
      final result = await store.pathFor('does-not-exist');
      expect(result, isA<ResultFailure<String>>());
    });

    test('delete removes the stored file', () async {
      final putResult = await store.put(sourceFile.path);
      final assetId = (putResult as Success<String>).value;
      final pathBefore =
          ((await store.pathFor(assetId)) as Success<String>).value;
      expect(File(pathBefore).existsSync(), isTrue);

      final deleteResult = await store.delete(assetId);
      expect(deleteResult, isA<Success<void>>());

      expect(File(pathBefore).existsSync(), isFalse);
      expect(await store.pathFor(assetId), isA<ResultFailure<String>>());
    });

    test('delete is a no-op for an unknown asset id', () async {
      final result = await store.delete('does-not-exist');
      expect(result, isA<Success<void>>());
    });

    test('multiple assets round-trip independently', () async {
      final second = File('${tempDir.path}/second.m4a')
        ..writeAsBytesSync([5, 6, 7]);

      final firstId =
          ((await store.put(sourceFile.path)) as Success<String>).value;
      final secondId =
          ((await store.put(second.path)) as Success<String>).value;

      expect(firstId, isNot(secondId));
      final firstPath =
          ((await store.pathFor(firstId)) as Success<String>).value;
      final secondPath =
          ((await store.pathFor(secondId)) as Success<String>).value;
      expect(File(firstPath).readAsBytesSync(), [1, 2, 3, 4]);
      expect(File(secondPath).readAsBytesSync(), [5, 6, 7]);
    });
  });
}
