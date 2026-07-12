import 'package:pieces/src/domain/piece_binary_store.dart';

/// A [PieceBinaryStore] that uploads nothing.
///
/// The base PDF already lives on-device (the local repositories keep the
/// binary), so in the local/mock composition there is nothing to upload. Bound
/// by default and in the headless gate (G2); the Firebase-backed store is
/// composed only under `useFirebase` (M3.6).
class NoopPieceBinaryStore implements PieceBinaryStore {
  /// Creates a [NoopPieceBinaryStore].
  const NoopPieceBinaryStore();

  @override
  Stream<UploadProgress> uploadBasePdf({
    required String pieceId,
    required String localPath,
    required String checksum,
  }) async* {
    // The bytes are already local; report an immediate no-op completion so the
    // import flow's progress step resolves at once.
    yield const UploadProgress.skipped();
  }
}
