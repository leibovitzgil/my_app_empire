import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// A [PieceBinaryStore] backed by Cloud Storage (`pieces/{id}/base.pdf`, per
/// `docs/duet_cloud_schema.md`) — the cloud counterpart to
/// [NoopPieceBinaryStore].
///
/// **Dedupe.** Before uploading it reads the stored object's `checksum` custom
/// metadata; a match means the identical PDF is already up for this piece
/// (a re-import, or `registerImportedPiece` of the same file), so the upload is
/// skipped. Objects are per-piece — there is deliberately no cross-piece
/// content-addressed store (schema "Dedupe decision").
///
/// **Ordering.** The caller creates the `pieces/{id}` document first (so the
/// Storage rules' membership lookup resolves), then uploads here; on success we
/// stamp `basePdfUploaded: true` on the piece document so a killed/retried app
/// can tell the binary is durably up (a resume/repair signal audited by M8.4).
///
/// Not wired into DI yet — M3.6 flips `useFirebase` onto this (the default
/// composition keeps the no-op store, so nothing here runs headless — G2).
class FirebasePieceBinaryStore implements PieceBinaryStore {
  /// Creates a [FirebasePieceBinaryStore].
  FirebasePieceBinaryStore({
    required FirebaseStorage storage,
    required FirebaseFirestore firestore,
  }) : _storage = storage,
       _firestore = firestore;

  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;

  Reference _basePdfRef(String pieceId) =>
      _storage.ref('pieces/$pieceId/base.pdf');

  @override
  Stream<UploadProgress> uploadBasePdf({
    required String pieceId,
    required String localPath,
    required String checksum,
  }) async* {
    final ref = _basePdfRef(pieceId);
    if (await _alreadyStored(ref, checksum)) {
      await _markUploaded(pieceId);
      yield const UploadProgress.skipped();
      return;
    }

    final task = ref.putFile(
      File(localPath),
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: <String, String>{'checksum': checksum},
      ),
    );
    try {
      await for (final snapshot in task.snapshotEvents) {
        switch (snapshot.state) {
          case TaskState.running:
          case TaskState.paused:
          case TaskState.success:
            yield UploadProgress(
              bytesTransferred: snapshot.bytesTransferred,
              totalBytes: snapshot.totalBytes,
            );
          case TaskState.canceled:
            return;
          case TaskState.error:
            break; // Surfaced by `await task` below.
        }
      }
      await task; // Throws on a terminal error, surfacing it as a stream error.
      await _markUploaded(pieceId);
    } finally {
      // If the subscriber cancelled mid-flight, abort the underlying upload so
      // it doesn't keep running detached.
      final state = task.snapshot.state;
      if (state == TaskState.running || state == TaskState.paused) {
        await task.cancel();
      }
    }
  }

  @override
  Future<Result<void>> downloadBasePdf({
    required String pieceId,
    required String destPath,
  }) => Result.guard<void>(() async {
    final file = File(destPath)..parent.createSync(recursive: true);
    // `writeToFile` streams the Storage object to disk; awaiting the task
    // throws on a terminal error (mapped to a Result failure by `guard`).
    // `PdfBinaryCache` verifies the written bytes against the checksum.
    await _basePdfRef(pieceId).writeToFile(file);
  });

  /// Whether an object already exists at [ref] with a matching `checksum`.
  Future<bool> _alreadyStored(Reference ref, String checksum) async {
    try {
      final metadata = await ref.getMetadata();
      return metadata.customMetadata?['checksum'] == checksum;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return false;
      rethrow;
    }
  }

  /// Records that the base PDF is durably uploaded (owner-only piece-metadata
  /// write; the immutable membership fields are untouched, so the M2.2 rules
  /// permit it).
  Future<void> _markUploaded(String pieceId) =>
      _firestore.collection('pieces').doc(pieceId).set(<String, dynamic>{
        'basePdfUploaded': true,
      }, SetOptions(merge: true));
}
