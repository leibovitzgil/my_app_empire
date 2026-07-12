import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';

/// Progress of a base-PDF upload (M3.3).
///
/// [fraction] is a 0..1 completion value. A [skipped] event means the object's
/// stored checksum already matched, so nothing was transferred (dedupe hit) —
/// its [fraction] is `1`.
class UploadProgress extends Equatable {
  /// Creates an [UploadProgress] for a transfer of [bytesTransferred] of
  /// [totalBytes].
  const UploadProgress({
    required this.bytesTransferred,
    required this.totalBytes,
    this.skipped = false,
  });

  /// A dedupe hit: the stored object already matched the requested
  /// `checksum`-equivalent content, so nothing was uploaded.
  const UploadProgress.skipped()
    : bytesTransferred = 0,
      totalBytes = 0,
      skipped = true;

  /// Bytes transferred so far.
  final int bytesTransferred;

  /// Total bytes to transfer (0 when [skipped] or not yet known).
  final int totalBytes;

  /// Whether the upload was skipped because the object already existed.
  final bool skipped;

  /// A 0..1 completion value: `1` when [skipped] or fully transferred, `0`
  /// while [totalBytes] is still unknown.
  double get fraction {
    if (skipped) return 1;
    if (totalBytes <= 0) return 0;
    return (bytesTransferred / totalBytes).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [bytesTransferred, totalBytes, skipped];
}

/// Contract for uploading a piece's base PDF to durable storage, streaming
/// progress. The read/download side (offline cache) is M3.4's `PdfBinaryCache`.
///
/// Kept a separate seam from `PieceRepository` (rather than folded into
/// `importPiece`) precisely so upload progress is *streamable* — the import
/// bloc renders a determinate bar from [uploadBasePdf]'s events. The download
/// side feeds `PdfBinaryCache` (M3.4).
abstract class PieceBinaryStore {
  /// Ensures the bytes at [localPath] (content-identified by [checksum]) are
  /// stored as [pieceId]'s base PDF, emitting [UploadProgress] as it goes and
  /// completing when the object is durably stored.
  ///
  /// An object whose stored checksum already matches [checksum] is **not**
  /// re-uploaded — a single [UploadProgress.skipped] is emitted and the stream
  /// completes. A failure surfaces as a stream error (the caller maps it to a
  /// `Result`-style failure, per G4). Cancelling the subscription aborts an
  /// in-flight upload.
  Stream<UploadProgress> uploadBasePdf({
    required String pieceId,
    required String localPath,
    required String checksum,
  });

  /// Downloads [pieceId]'s base PDF to [destPath], overwriting it, completing
  /// once written. Fails (rather than throwing) when there is no remote object
  /// or the transfer errors. The caller (`PdfBinaryCache`) verifies the written
  /// bytes against the expected checksum — this method does not.
  Future<Result<void>> downloadBasePdf({
    required String pieceId,
    required String destPath,
  });
}
