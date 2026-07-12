import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/src/domain/piece_binary_store.dart';

/// A [PieceBinaryStore] that neither uploads nor downloads.
///
/// The base PDF already lives on-device (the local repositories keep the
/// binary), so in the local/mock composition there is nothing to transfer.
/// Bound by default and in the headless gate (G2); the Firebase-backed store is
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

  @override
  Future<Result<void>> downloadBasePdf({
    required String pieceId,
    required String destPath,
  }) async =>
      // Nothing to download — the local composition resolves the base PDF from
      // its on-device path, so `PdfBinaryCache` never reaches this.
      ResultFailure<void>(
        StateError('NoopPieceBinaryStore cannot download $pieceId'),
      );
}
