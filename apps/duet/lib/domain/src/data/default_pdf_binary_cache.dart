import 'dart:convert';
import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/src/domain/pdf_binary_cache.dart';
import 'package:duet/domain/src/domain/piece.dart';
import 'package:duet/domain/src/domain/piece_binary_store.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

/// The canonical [PdfBinaryCache]: resolve order is **cache hit → on-device
/// copy → download**, so the local composition (binary already staged by the
/// local repositories) returns the on-device path directly with no second blob
/// store, while the cloud composition downloads once into a checksum-keyed
/// cache that subsequent (even offline) opens hit.
///
/// Downloads delegate to the injected [PieceBinaryStore]; the bytes are
/// verified against [Piece.basePdfChecksum] and a mismatch triggers exactly one
/// re-download before failing honestly. A simple total-size cap evicts the
/// least-recently-opened cached files.
class DefaultPdfBinaryCache implements PdfBinaryCache {
  /// Creates a [DefaultPdfBinaryCache]. [maxCacheBytes] caps the downloaded
  /// cache directory (default 1 GB); [documentsDirectory]/[clock] are injectable
  /// for tests.
  DefaultPdfBinaryCache({
    required PieceBinaryStore binaryStore,
    required PdfRenderService pdfRenderService,
    required LocalStorageService storage,
    Future<Directory> Function()? documentsDirectory,
    int maxCacheBytes = _defaultMaxCacheBytes,
    DateTime Function()? clock,
  }) : _binaryStore = binaryStore,
       _pdfRenderService = pdfRenderService,
       _storage = storage,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _maxCacheBytes = maxCacheBytes,
       _now = clock ?? DateTime.now;

  static const int _defaultMaxCacheBytes = 1024 * 1024 * 1024; // 1 GB.
  static const String _dirName = 'pieces_cache';
  static const String _lruKey = 'pieces.cache.lastOpened';

  final PieceBinaryStore _binaryStore;
  final PdfRenderService _pdfRenderService;
  final LocalStorageService _storage;
  final Future<Directory> Function() _documentsDirectory;
  final int _maxCacheBytes;
  final DateTime Function() _now;

  Future<Directory> _cacheDir() async {
    final documents = await _documentsDirectory();
    return Directory(p.join(documents.path, _dirName));
  }

  Future<File> _cacheFile(String checksum) async =>
      File(p.join((await _cacheDir()).path, '$checksum.pdf'));

  @override
  Future<Result<String>> pathFor(Piece piece) => Result.guard<String>(() async {
    final cacheFile = await _cacheFile(piece.basePdfChecksum);
    if (cacheFile.existsSync()) {
      await _touch(piece.basePdfChecksum);
      return cacheFile.path;
    }
    // On-device copy (local composition): return it directly — the cache
    // dir stays reserved for downloaded copies, so there's no second store.
    final local = piece.basePdfPath;
    if (local.isNotEmpty && File(local).existsSync()) {
      return local;
    }
    // Cloud miss: download into the cache, verifying integrity.
    await _downloadVerified(piece, cacheFile);
    await _touch(piece.basePdfChecksum);
    await _evictIfOverCap();
    return cacheFile.path;
  });

  Future<void> _downloadVerified(Piece piece, File cacheFile) async {
    cacheFile.parent.createSync(recursive: true);
    // Download, verify, and on a checksum mismatch re-download once (a partial
    // or corrupt transfer) before giving up.
    for (var attempt = 0; attempt < 2; attempt++) {
      (await _binaryStore.downloadBasePdf(
        pieceId: piece.id,
        destPath: cacheFile.path,
      )).orThrow();
      final actual = (await _pdfRenderService.checksum(
        cacheFile.path,
      )).orThrow();
      if (actual == piece.basePdfChecksum) return;
      if (cacheFile.existsSync()) cacheFile.deleteSync();
    }
    throw StateError(
      'Base PDF for ${piece.id} failed checksum verification after re-download',
    );
  }

  Map<String, int> _lru() {
    final raw = _storage.getString(_lruKey);
    if (raw == null) return <String, int>{};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as int),
    );
  }

  Future<void> _touch(String checksum) {
    final next = _lru()..[checksum] = _now().microsecondsSinceEpoch;
    return _storage.setString(_lruKey, jsonEncode(next));
  }

  /// Evicts least-recently-opened cached files while the cache directory
  /// exceeds [_maxCacheBytes].
  Future<void> _evictIfOverCap() async {
    final dir = await _cacheDir();
    if (!dir.existsSync()) return;
    final files = dir.listSync().whereType<File>().toList();
    var total = files.fold<int>(0, (sum, file) => sum + file.lengthSync());
    if (total <= _maxCacheBytes) return;

    final lru = _lru();
    int lastOpened(File file) => lru[_checksumOf(file)] ?? 0;
    files.sort((a, b) => lastOpened(a).compareTo(lastOpened(b)));

    final next = Map<String, int>.from(lru);
    for (final file in files) {
      if (total <= _maxCacheBytes) break;
      total -= file.lengthSync();
      file.deleteSync();
      next.remove(_checksumOf(file));
    }
    await _storage.setString(_lruKey, jsonEncode(next));
  }

  String _checksumOf(File file) => p.basenameWithoutExtension(file.path);
}
