import 'package:core_utils/core_utils.dart';
import 'package:pieces/src/domain/piece.dart';

/// Resolves a local, readable file path to a piece's base PDF — from an
/// on-device copy when present, otherwise by downloading and caching it.
///
/// The reader opens the returned path. This is the seam that lets a musician
/// open her sheets offline once they've been fetched (architecture decision 2):
/// a cache hit never touches the network.
// ignore: one_member_abstracts
abstract class PdfBinaryCache {
  /// Returns a local path to [piece]'s base PDF, fetching and caching it (keyed
  /// by `basePdfChecksum`, integrity-verified) on a cache miss.
  ///
  /// Fails (per G4) when the binary can't be resolved — offline with nothing
  /// cached, or a download that never matches the expected checksum.
  Future<Result<String>> pathFor(Piece piece);
}
