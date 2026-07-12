import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:duet/data/audio_object_store.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// An [AudioObjectStore] backed by Cloud Storage (`pieces/{id}/audio/{assetId}`,
/// per `docs/duet_cloud_schema.md`). The M2.2 rules already scope these objects
/// to participants.
///
/// Not unit-tested (there is no Storage fake in the toolkit, as with the other
/// Firebase Storage impls); its transfer is emulator-verified, and the
/// `CloudAudioAssetStore` orchestration around it is fake-tested. Not wired
/// into DI yet — M3.6 flips `useFirebase`.
class FirebaseAudioObjectStore implements AudioObjectStore {
  /// Creates a [FirebaseAudioObjectStore].
  FirebaseAudioObjectStore({required FirebaseStorage storage})
    : _storage = storage;

  final FirebaseStorage _storage;

  Reference _ref(String pieceId, String assetId) =>
      _storage.ref('pieces/$pieceId/audio/$assetId');

  @override
  Future<Result<void>> upload({
    required String pieceId,
    required String assetId,
    required String localPath,
  }) => Result.guard<void>(() async {
    await _ref(pieceId, assetId).putFile(File(localPath));
  });

  @override
  Future<Result<void>> download({
    required String pieceId,
    required String assetId,
    required String destPath,
  }) => Result.guard<void>(() async {
    final file = File(destPath)..parent.createSync(recursive: true);
    await _ref(pieceId, assetId).writeToFile(file);
  });

  @override
  Future<Result<void>> delete({
    required String pieceId,
    required String assetId,
  }) => Result.guard<void>(() async {
    try {
      await _ref(pieceId, assetId).delete();
    } on FirebaseException catch (e) {
      // Already gone is success — the delete is idempotent.
      if (e.code != 'object-not-found') rethrow;
    }
  });
}
