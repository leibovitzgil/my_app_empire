import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:core_utils/core_utils.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pieces/pieces.dart';
import 'package:review_sync/src/data/review_manifest.dart';
import 'package:review_sync/src/data/review_sync_exception.dart';
import 'package:share_plus/share_plus.dart';

/// Invoked after a successful [FileShareReviewSyncService.importBundle] that
/// actually changed something locally, so the app can surface a local
/// notification. `packages/services/notifications`'s `NotificationsManager`
/// currently only wraps Firebase Cloud Messaging permission flows and has no
/// API to post a device-local notification, so this is a plain callback hook
/// rather than a direct dependency on that package; wiring it to a real
/// local notification (e.g. via `flutter_local_notifications`, once added)
/// is left to the app layer.
typedef ReviewSyncNotifier =
    Future<void> Function({required String title, required String body});

/// A [ReviewSyncService] that packages a piece's annotations into a `.duet`
/// zip bundle (`package:archive`), hands it off via `package:share_plus`'s
/// OS share sheet, and reads bundles back in — applying the local-first,
/// per-author "stale-drop" sync model: a bundle only ever contains one
/// author's slice, and an import whose `exportedAtMillis` is not newer than
/// the last-applied revision for that (piece, author) is a silent no-op.
class FileShareReviewSyncService implements ReviewSyncService {
  /// Creates a [FileShareReviewSyncService].
  ///
  /// [bundlesDirectory] is used both to write exported `.duet` files and as
  /// import scratch space; it defaults to `getTemporaryDirectory` since
  /// bundles are transient hand-off artifacts, not the app's persistent
  /// piece/audio storage. [shareInvoker] defaults to `SharePlus.instance
  /// .share`; inject a fake in tests to avoid the platform channel.
  FileShareReviewSyncService({
    required PieceRepository pieceRepository,
    required AnnotationRepository annotationRepository,
    required AudioAssetStore audioAssetStore,
    required LocalStorageService storage,
    required String Function() currentUserId,
    String? Function()? currentUserName,
    Future<Directory> Function()? bundlesDirectory,
    DateTime Function()? clock,
    Future<ShareResult> Function(ShareParams params)? shareInvoker,
    ReviewSyncNotifier? onImported,
  }) : _pieceRepository = pieceRepository,
       _annotationRepository = annotationRepository,
       _audioAssetStore = audioAssetStore,
       _storage = storage,
       _currentUserId = currentUserId,
       _currentUserName = currentUserName ?? (() => null),
       _bundlesDirectory = bundlesDirectory ?? getTemporaryDirectory,
       _now = clock ?? DateTime.now,
       _shareInvoker = shareInvoker ?? SharePlus.instance.share,
       _onImported = onImported;

  final PieceRepository _pieceRepository;
  final AnnotationRepository _annotationRepository;
  final AudioAssetStore _audioAssetStore;
  final LocalStorageService _storage;
  final String Function() _currentUserId;
  final String? Function() _currentUserName;
  final Future<Directory> Function() _bundlesDirectory;
  final DateTime Function() _now;
  final Future<ShareResult> Function(ShareParams params) _shareInvoker;
  final ReviewSyncNotifier? _onImported;

  // Tracks, per piece, whether a bundle including the base PDF has ever been
  // exported. Judgment call (see task doc): rather than embedding the PDF on
  // every export (wasteful) or never (breaks a fresh receiver), the *first*
  // bundle ever exported for a piece embeds the PDF + filename; every
  // export after that assumes the recipient already has it. This is scoped
  // per-piece, not per-author, since only the owner's export ever needs to
  // carry the PDF in the first place.
  String _baseSharedKey(String pieceId) => 'review_sync.base_shared.$pieceId';

  String _lastAppliedKey(String pieceId, String authorId) =>
      'review_sync.last_applied.$pieceId.$authorId';

  Future<Piece> _requirePiece(String pieceId) async {
    final result = await _pieceRepository.getPiece(pieceId);
    return switch (result) {
      Success<Piece>(:final value) => value,
      ResultFailure<Piece>(:final error) => throw ReviewSyncException(
        'Unknown piece: $pieceId ($error)',
      ),
    };
  }

  /// Resolves the local [Piece] a bundle's [manifest] applies to, creating
  /// it on the fly from the bundle's embedded PDF if this is a genuine
  /// cross-device "first share" — the receiver has never seen
  /// `manifest.pieceId` before, and the manifest carries the base PDF
  /// precisely for this case (see `exportBundle`'s `_baseSharedKey` doc).
  /// Fails the same way [_requirePiece] does if there's no local copy and
  /// no embedded PDF to create one from.
  ///
  /// If the piece *does* already exist locally, its `basePdfChecksum` is
  /// compared against the manifest's to catch drift between copies — a
  /// mismatch means the region-anchored annotations below could silently
  /// misalign, so this hard-fails rather than applying them.
  Future<Piece> _resolvePiece(ReviewManifest manifest, Archive archive) async {
    final existing = await _pieceRepository.getPiece(manifest.pieceId);
    switch (existing) {
      case Success<Piece>(:final value):
        if (value.basePdfChecksum != manifest.basePdfChecksum) {
          throw ReviewSyncException(
            'Base PDF checksum mismatch for ${manifest.pieceId}: the local '
            "copy has drifted from the sender's. Refusing to apply "
            'region-anchored annotations that could silently misalign.',
          );
        }
        return value;
      case ResultFailure<Piece>():
        return _importPieceFromBundle(manifest, archive);
    }
  }

  Future<Piece> _importPieceFromBundle(
    ReviewManifest manifest,
    Archive archive,
  ) async {
    final pdfFilename = manifest.basePdfFilename;
    if (pdfFilename == null) {
      throw ReviewSyncException(
        'Unknown piece: ${manifest.pieceId} (no local copy, and this '
        'bundle has no embedded PDF to create one from)',
      );
    }
    final pdfEntries = archive.files.where(
      (f) => f.name == 'pdf/$pdfFilename',
    );
    if (pdfEntries.isEmpty) {
      throw ReviewSyncException(
        'Bundle is missing the embedded PDF (pdf/$pdfFilename) needed to '
        'create ${manifest.pieceId} locally',
      );
    }

    final tempDir = await _bundlesDirectory();
    if (!tempDir.existsSync()) tempDir.createSync(recursive: true);
    final tempPath = p.join(
      tempDir.path,
      'import_${manifest.pieceId}${p.extension(pdfFilename)}',
    );
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(pdfEntries.first.content as List<int>);

    final currentUserId = _currentUserId();
    // Only the owner's export ever embeds the base PDF (see
    // `_baseSharedKey`), so a first-share bundle's author is always the
    // owner; the receiving device belongs to the (currently signed-in)
    // collaborator, unless this is the owner's own device re-importing their
    // own bundle.
    final isSelfImport = currentUserId == manifest.authorId;

    final Piece piece;
    try {
      piece = (await _pieceRepository.registerImportedPiece(
        pieceId: manifest.pieceId,
        title: manifest.pieceTitle,
        ownerId: manifest.authorId,
        ownerName: manifest.authorName,
        collaboratorId: isSelfImport ? null : currentUserId,
        collaboratorName: isSelfImport ? null : _currentUserName(),
        sourcePath: tempPath,
      )).orThrow();
    } finally {
      if (tempFile.existsSync()) await tempFile.delete();
    }

    if (piece.basePdfChecksum != manifest.basePdfChecksum) {
      throw ReviewSyncException(
        'Imported PDF checksum for ${manifest.pieceId} does not match the '
        "manifest's basePdfChecksum — the transferred file may be corrupt",
      );
    }
    return piece;
  }

  PieceRole _roleOf(Piece piece, String authorId) =>
      piece.ownerId == authorId ? PieceRole.owner : PieceRole.collaborator;

  @override
  Future<Result<ExportedBundle>> exportBundle(
    String pieceId, {
    String? authorId,
  }) => Result.guard<ExportedBundle>(() async {
    final resolvedAuthorId = authorId ?? _currentUserId();
    final piece = await _requirePiece(pieceId);
    final annotations = await _annotationRepository.watch(pieceId).first;
    final layer = annotations.layers.firstWhere(
      (l) => l.ownerId == resolvedAuthorId,
      orElse: () => InkLayer(
        ownerId: resolvedAuthorId,
        role: _roleOf(piece, resolvedAuthorId),
        strokes: const [],
      ),
    );
    final authorNotes = annotations.audioNotes
        .where((n) => n.authorId == resolvedAuthorId)
        .toList();

    final archive = Archive();
    final audioEntries = <ManifestAudioEntry>[];
    for (final note in authorNotes) {
      final pathResult = await _audioAssetStore.pathFor(note.audioAssetId);
      final assetPath = switch (pathResult) {
        Success<String>(:final value) => value,
        ResultFailure<String>(:final error) => throw ReviewSyncException(
          'Missing audio asset for note ${note.id}: $error',
        ),
      };
      final fileName = '${note.id}${p.extension(assetPath)}';
      final bytes = await File(assetPath).readAsBytes();
      archive.addFile(ArchiveFile('audio/$fileName', bytes.length, bytes));
      audioEntries.add(ManifestAudioEntry(note: note, audioFile: fileName));
    }

    final baseSharedKey = _baseSharedKey(pieceId);
    final includeBasePdf = _storage.getBool(baseSharedKey) != true;
    String? pdfFilename;
    final pdfFile = File(piece.basePdfPath);
    if (includeBasePdf && pdfFile.existsSync()) {
      pdfFilename = p.basename(piece.basePdfPath);
      final pdfBytes = await pdfFile.readAsBytes();
      archive.addFile(
        ArchiveFile('pdf/$pdfFilename', pdfBytes.length, pdfBytes),
      );
    }

    final now = _now();
    // Only attached when exporting as the current device's own user (the
    // overwhelming common case — `authorId` is otherwise only overridden by
    // tests): a different, explicitly-passed `authorId` isn't someone whose
    // display name this device could actually know.
    final authorName = resolvedAuthorId == _currentUserId()
        ? _currentUserName()
        : null;
    final manifest = ReviewManifest(
      version: 1,
      pieceId: pieceId,
      pieceTitle: piece.title,
      authorId: resolvedAuthorId,
      authorName: authorName,
      exportedAtMillis: now.millisecondsSinceEpoch,
      basePdfChecksum: piece.basePdfChecksum,
      basePdfFilename: pdfFilename,
      strokes: layer.strokes,
      audioEntries: audioEntries,
    );
    archive.addFile(
      ArchiveFile.string('manifest.json', jsonEncode(manifest.toJson())),
    );

    final zipBytes = ZipEncoder().encode(archive);

    final dir = await _bundlesDirectory();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final fileName =
        'duet_${pieceId}_${resolvedAuthorId}_'
        '${now.millisecondsSinceEpoch}.duet';
    final bundleFile = File(p.join(dir.path, fileName));
    await bundleFile.writeAsBytes(zipBytes);

    if (pdfFilename != null) {
      await _storage.setBool(baseSharedKey, true);
    }

    return ExportedBundle(
      pieceId: pieceId,
      filePath: bundleFile.path,
      manifest: ReviewBundleSummary(
        pieceTitle: piece.title,
        strokeCount: layer.strokes.length,
        audioNoteCount: authorNotes.length,
        exportedAt: now,
      ),
    );
  });

  @override
  Future<Result<void>> share(ExportedBundle bundle) =>
      Result.guard<void>(() async {
        await _shareInvoker(
          ShareParams(
            files: [XFile(bundle.filePath)],
            subject: 'Duet review bundle: ${bundle.manifest.pieceTitle}',
          ),
        );
      });

  @override
  Future<Result<ReviewBundleSummary>> importBundle(String filePath) =>
      Result.guard<ReviewBundleSummary>(() async {
        final bytes = await File(filePath).readAsBytes();
        final Archive archive;
        try {
          archive = ZipDecoder().decodeBytes(bytes);
        } on Object catch (error) {
          throw ReviewSyncException('Not a valid .duet bundle: $error');
        }

        final manifestEntries = archive.files.where(
          (f) => f.name == 'manifest.json',
        );
        if (manifestEntries.isEmpty) {
          throw const ReviewSyncException('Bundle is missing manifest.json');
        }
        final manifestJson =
            jsonDecode(utf8.decode(manifestEntries.first.content as List<int>))
                as Map<String, dynamic>;
        final manifest = ReviewManifest.fromJson(manifestJson);

        final piece = await _resolvePiece(manifest, archive);

        final lastAppliedKey = _lastAppliedKey(
          manifest.pieceId,
          manifest.authorId,
        );
        final lastApplied = _storage.getInt(lastAppliedKey) ?? 0;
        if (manifest.exportedAtMillis <= lastApplied) {
          // Stale bundle (already-applied or out-of-order); per the sync
          // model this is a silent no-op — signalled here via zero counts.
          return ReviewBundleSummary(
            pieceTitle: piece.title,
            strokeCount: 0,
            audioNoteCount: 0,
            exportedAt: DateTime.fromMillisecondsSinceEpoch(
              manifest.exportedAtMillis,
            ),
          );
        }

        final role = _roleOf(piece, manifest.authorId);
        final tempDir = await _bundlesDirectory();
        if (!tempDir.existsSync()) tempDir.createSync(recursive: true);

        final newAudioNotes = <AudioNote>[];
        for (final entry in manifest.audioEntries) {
          final zipEntries = archive.files.where(
            (f) => f.name == 'audio/${entry.audioFile}',
          );
          if (zipEntries.isEmpty) {
            throw ReviewSyncException(
              'Missing audio file for note ${entry.note.id}',
            );
          }
          final audioBytes = zipEntries.first.content as List<int>;
          final tempPath = p.join(
            tempDir.path,
            'import_${entry.note.id}${p.extension(entry.audioFile)}',
          );
          final tempFile = File(tempPath);
          await tempFile.writeAsBytes(audioBytes);
          final putResult = await _audioAssetStore.put(tempPath);
          if (tempFile.existsSync()) await tempFile.delete();
          final assetId = switch (putResult) {
            Success<String>(:final value) => value,
            ResultFailure<String>(:final error) => throw ReviewSyncException(
              'Failed to store imported audio for note ${entry.note.id}: '
              '$error',
            ),
          };
          newAudioNotes.add(
            AudioNote(
              id: entry.note.id,
              authorId: entry.note.authorId,
              audioAssetId: assetId,
              pageIndex: entry.note.pageIndex,
              durationMs: entry.note.durationMs,
              region: entry.note.region,
              createdAt: entry.note.createdAt,
            ),
          );
        }

        // Capture the author's previous audio assets so they can be cleaned
        // up once the replacement below has succeeded, avoiding orphaned
        // files without risking data loss if the replace itself fails.
        final current = await _annotationRepository
            .watch(manifest.pieceId)
            .first;
        final staleAssetIds = current.audioNotes
            .where((n) => n.authorId == manifest.authorId)
            .map((n) => n.audioAssetId)
            .toSet();

        (await _annotationRepository.replaceAuthorSlice(
          manifest.pieceId,
          manifest.authorId,
          role: role,
          strokes: manifest.strokes,
          audioNotes: newAudioNotes,
        )).orThrow();

        for (final assetId in staleAssetIds) {
          await _audioAssetStore.delete(assetId);
        }

        await _storage.setInt(lastAppliedKey, manifest.exportedAtMillis);

        final changed = manifest.strokes.isNotEmpty || newAudioNotes.isNotEmpty;
        final onImported = _onImported;
        if (changed && onImported != null) {
          // The author's display name travels with the manifest (see
          // `exportBundle`'s `authorName`), not the receiving device's own
          // identity — it's whoever left the feedback, not who's reading it.
          // Older bundles (or an author who had no display name set at
          // export time) carry `null`, so this falls back to generic copy
          // rather than showing a blank/placeholder name.
          final authorName = manifest.authorName;
          await onImported(
            title: authorName != null
                ? 'New feedback from $authorName'
                : 'New review feedback',
            body:
                '${piece.title}: ${manifest.strokes.length} strokes, '
                '${newAudioNotes.length} notes',
          );
        }

        return ReviewBundleSummary(
          pieceTitle: piece.title,
          strokeCount: manifest.strokes.length,
          audioNoteCount: newAudioNotes.length,
          exportedAt: DateTime.fromMillisecondsSinceEpoch(
            manifest.exportedAtMillis,
          ),
        );
      });
}
