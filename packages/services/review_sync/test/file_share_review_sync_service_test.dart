import 'dart:convert';
import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:pieces/pieces.dart';
import 'package:review_sync/review_sync.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePieceRepository implements PieceRepository {
  _FakePieceRepository(Piece piece) : pieces = [piece];

  /// Constructs with an explicit (possibly empty) starting set of pieces —
  /// used to simulate a receiver that has never seen a given piece before.
  _FakePieceRepository.withPieces(this.pieces);

  List<Piece> pieces;

  @override
  Future<Result<Piece>> getPiece(String pieceId) async {
    for (final piece in pieces) {
      if (piece.id == pieceId) return Success(piece);
    }
    return ResultFailure<Piece>(StateError('Unknown piece: $pieceId'));
  }

  @override
  Future<Result<void>> deletePiece(String pieceId) =>
      throw UnimplementedError();

  @override
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
    String? ownerName,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> leavePiece(String pieceId) => throw UnimplementedError();

  @override
  Future<Result<void>> renamePiece(String pieceId, String title) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> addCollaborator(
    String pieceId, {
    required String userId,
    String? name,
    String? email,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> removeCollaborator(String pieceId, String userId) =>
      throw UnimplementedError();

  @override
  Future<Result<Piece>> pairCollaborator(
    String pieceId, {
    required String collaboratorId,
    String? collaboratorName,
    String? collaboratorEmail,
    String? ownerName,
  }) => throw UnimplementedError();

  /// A simple, deterministic, content-based "checksum" (sum of byte
  /// values) — good enough for this fake to prove real checksum
  /// verification wiring without depending on `pdf_rendering`.
  Future<String> _checksumOf(String path) async {
    final bytes = await File(path).readAsBytes();
    return bytes.fold<int>(0, (sum, byte) => sum + byte).toString();
  }

  @override
  Future<Result<Piece>> registerImportedPiece({
    required String pieceId,
    required String title,
    required String ownerId,
    required String sourcePath,
    String? collaboratorId,
    String? ownerName,
    String? collaboratorName,
  }) async {
    if (pieces.any((p) => p.id == pieceId)) {
      return ResultFailure<Piece>(
        StateError('Piece already exists locally: $pieceId'),
      );
    }
    final now = DateTime(2024);
    final piece = Piece(
      id: pieceId,
      title: title,
      basePdfChecksum: await _checksumOf(sourcePath),
      basePdfPath: sourcePath,
      ownerId: ownerId,
      ownerName: ownerName,
      collaborators: collaboratorId == null
          ? null
          : [Collaborator(uid: collaboratorId, name: collaboratorName)],
      createdAt: now,
      updatedAt: now,
    );
    pieces = [...pieces, piece];
    return Success(piece);
  }

  @override
  Stream<List<Piece>> watchPieces() => throw UnimplementedError();
}

/// A minimal in-memory [AnnotationRepository] fake, scoped to what
/// `FileShareReviewSyncService` actually calls (`watch`, `replaceAuthorSlice`),
/// plus a `seed` helper so tests can set up "device" state directly.
class _FakeAnnotationRepository implements AnnotationRepository {
  final Map<String, PieceAnnotations> _data = {};

  PieceAnnotations _for(String pieceId) =>
      _data[pieceId] ?? PieceAnnotations.empty(pieceId);

  void seed(String pieceId, PieceAnnotations annotations) {
    _data[pieceId] = annotations;
  }

  @override
  Stream<PieceAnnotations> watch(String pieceId) async* {
    yield _for(pieceId);
  }

  @override
  Future<Result<void>> replaceAuthorSlice(
    String pieceId,
    String authorId, {
    required PieceRole role,
    required List<InkStroke> strokes,
    required List<AudioNote> audioNotes,
  }) async {
    final current = _for(pieceId);
    _data[pieceId] = PieceAnnotations(
      pieceId: pieceId,
      layers: [
        ...current.layers.where((l) => l.ownerId != authorId),
        InkLayer(ownerId: authorId, role: role, strokes: strokes),
      ],
      audioNotes: [
        ...current.audioNotes.where((n) => n.authorId != authorId),
        ...audioNotes,
      ],
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> addStroke(String pieceId, InkStroke stroke) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> addAudioNote(String pieceId, AudioNote note) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> clearPiece(String pieceId) async {
    _data.remove(pieceId);
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteAudioNote(String pieceId, String noteId) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> eraseStroke(String pieceId, String strokeId) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> removeAuthorSlice(String pieceId, String authorId) =>
      throw UnimplementedError();
}

/// A minimal in-memory [AudioAssetStore] fake keyed by a generated id, with
/// `pathFor` materializing a real temp file so callers using `dart:io` can
/// read it like the real, on-disk implementation.
class _FakeAudioAssetStore implements AudioAssetStore {
  _FakeAudioAssetStore(this._scratchDir, {String label = 'asset'})
    : _label = label;

  final Directory _scratchDir;
  final String _label;
  final Map<String, List<int>> _files = {};
  int _seq = 0;

  @override
  Future<Result<String>> put(String sourcePath) async {
    final id = '$_label-${_seq++}';
    _files[id] = await File(sourcePath).readAsBytes();
    return Success(id);
  }

  @override
  Future<Result<String>> pathFor(String assetId) async {
    final bytes = _files[assetId];
    if (bytes == null) {
      return ResultFailure<String>(StateError('Unknown asset: $assetId'));
    }
    final file = File('${_scratchDir.path}/$assetId.bin')
      ..writeAsBytesSync(bytes);
    return Success(file.path);
  }

  @override
  Future<Result<void>> delete(String assetId) async {
    _files.remove(assetId);
    return const Success(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final piece = Piece(
    id: 'piece-1',
    title: 'Clair de Lune',
    basePdfChecksum: 'checksum-abc',
    basePdfPath: '',
    ownerId: 'owner-1',
    collaborators: const [Collaborator(uid: 'collaborator-1')],
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  InkStroke stroke(String id) => InkStroke(
    id: id,
    authorId: 'owner-1',
    pageIndex: 0,
    colorId: 'red',
    points: const [InkPoint(x: 0.1, y: 0.1)],
  );

  AudioNote note(String id, {required String audioAssetId}) => AudioNote(
    id: id,
    authorId: 'owner-1',
    audioAssetId: audioAssetId,
    pageIndex: 0,
    durationMs: 3000,
    region: const Region(
      pageIndex: 0,
      left: 0,
      top: 0,
      width: 0.2,
      height: 0.1,
    ),
    createdAt: DateTime(2024),
  );

  group('FileShareReviewSyncService', () {
    late Directory tempDir;
    late Directory senderAudioDir;
    late Directory receiverAudioDir;
    late LocalStorageService storage;
    late _FakeAnnotationRepository senderAnnotations;
    late _FakeAudioAssetStore senderAudioStore;
    late File senderAudioFile;
    late String senderAssetId;
    late FileShareReviewSyncService senderService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('review_sync_test');
      senderAudioDir = Directory('${tempDir.path}/sender')..createSync();
      receiverAudioDir = Directory('${tempDir.path}/receiver')..createSync();

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);

      senderAnnotations = _FakeAnnotationRepository();
      senderAudioStore = _FakeAudioAssetStore(
        senderAudioDir,
        label: 'sender-asset',
      );

      senderAudioFile = File('${senderAudioDir.path}/recording.m4a')
        ..writeAsBytesSync([1, 2, 3, 4, 5]);
      final putResult = await senderAudioStore.put(senderAudioFile.path);
      senderAssetId = (putResult as Success<String>).value;

      senderAnnotations.seed(
        piece.id,
        PieceAnnotations(
          pieceId: piece.id,
          layers: [
            InkLayer(
              ownerId: 'owner-1',
              role: PieceRole.owner,
              strokes: [stroke('s1'), stroke('s2')],
            ),
          ],
          audioNotes: [note('n1', audioAssetId: senderAssetId)],
        ),
      );

      senderService = FileShareReviewSyncService(
        pieceRepository: _FakePieceRepository(piece),
        annotationRepository: senderAnnotations,
        audioAssetStore: senderAudioStore,
        storage: storage,
        currentUserId: () => 'owner-1',
        bundlesDirectory: () async => tempDir,
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test(
      "exportBundle packages the author's own strokes and audio notes",
      () async {
        final result = await senderService.exportBundle(piece.id);

        expect(result, isA<Success<ExportedBundle>>());
        final bundle = (result as Success<ExportedBundle>).value;
        expect(bundle.manifest.strokeCount, 2);
        expect(bundle.manifest.audioNoteCount, 1);
        expect(File(bundle.filePath).existsSync(), isTrue);
      },
    );

    test(
      'the first export embeds the base PDF; the second does not',
      () async {
        final pdfPath = '${tempDir.path}/base.pdf';
        File(pdfPath).writeAsStringSync('%PDF-1.4');
        final pieceWithPdf = Piece(
          id: piece.id,
          title: piece.title,
          basePdfChecksum: piece.basePdfChecksum,
          basePdfPath: pdfPath,
          ownerId: piece.ownerId,
          collaborators: piece.collaborators,
          createdAt: piece.createdAt,
          updatedAt: piece.updatedAt,
        );
        final service = FileShareReviewSyncService(
          pieceRepository: _FakePieceRepository(pieceWithPdf),
          annotationRepository: senderAnnotations,
          audioAssetStore: senderAudioStore,
          storage: storage,
          currentUserId: () => 'owner-1',
          bundlesDirectory: () async => tempDir,
        );

        final first = await service.exportBundle(piece.id);
        final second = await service.exportBundle(piece.id);

        final firstBytes = File(
          (first as Success<ExportedBundle>).value.filePath,
        ).readAsBytesSync();
        final secondBytes = File(
          (second as Success<ExportedBundle>).value.filePath,
        ).readAsBytesSync();

        // A bundle embedding the PDF is larger than one that doesn't.
        expect(firstBytes.length, greaterThan(secondBytes.length));
      },
    );

    test('share hands the bundle file to the injected share invoker', () async {
      ShareParams? capturedParams;
      final service = FileShareReviewSyncService(
        pieceRepository: _FakePieceRepository(piece),
        annotationRepository: senderAnnotations,
        audioAssetStore: senderAudioStore,
        storage: storage,
        currentUserId: () => 'owner-1',
        bundlesDirectory: () async => tempDir,
        shareInvoker: (params) async {
          capturedParams = params;
          return const ShareResult('ok', ShareResultStatus.success);
        },
      );
      final exportResult = await service.exportBundle(piece.id);
      final bundle = (exportResult as Success<ExportedBundle>).value;

      final shareResult = await service.share(bundle);

      expect(shareResult, isA<Success<void>>());
      expect(capturedParams, isNotNull);
      expect(capturedParams!.files!.single.path, bundle.filePath);
    });

    test(
      "importBundle applies the author's slice into a fresh receiver and "
      "copies audio into the receiver's own asset store",
      () async {
        final exportResult = await senderService.exportBundle(piece.id);
        final bundle = (exportResult as Success<ExportedBundle>).value;

        final receiverAnnotations = _FakeAnnotationRepository();
        final receiverAudioStore = _FakeAudioAssetStore(
          receiverAudioDir,
          label: 'receiver-asset',
        );
        final receiverService = FileShareReviewSyncService(
          pieceRepository: _FakePieceRepository(piece),
          annotationRepository: receiverAnnotations,
          audioAssetStore: receiverAudioStore,
          storage: storage,
          currentUserId: () => 'collaborator-1',
          bundlesDirectory: () async => tempDir,
        );

        final importResult = await receiverService.importBundle(
          bundle.filePath,
        );

        expect(importResult, isA<Success<ReviewBundleSummary>>());
        final summary = (importResult as Success<ReviewBundleSummary>).value;
        expect(summary.strokeCount, 2);
        expect(summary.audioNoteCount, 1);

        final receiverState = await receiverAnnotations.watch(piece.id).first;
        expect(
          receiverState.layers.single.strokes.map((s) => s.id).toSet(),
          {'s1', 's2'},
        );
        final importedNote = receiverState.audioNotes.single;
        expect(importedNote.id, 'n1');
        // The imported note must reference a *new*, receiver-local asset id
        // — asset ids aren't synced across devices.
        expect(importedNote.audioAssetId, isNot(senderAssetId));
        final importedPath = await receiverAudioStore.pathFor(
          importedNote.audioAssetId,
        );
        expect(
          File((importedPath as Success<String>).value).readAsBytesSync(),
          [1, 2, 3, 4, 5],
        );
      },
    );

    test(
      'importBundle preserves fractional stroke and audio-region '
      'coordinates exactly through the export/import round trip',
      () async {
        const precisePoints = [
          InkPoint(x: 0.123456, y: 0.654321),
          InkPoint(x: 0.987654, y: 0.010203),
        ];
        const preciseRegion = Region(
          pageIndex: 0,
          left: 0.111111,
          top: 0.222222,
          width: 0.333333,
          height: 0.098765,
        );
        senderAnnotations.seed(
          piece.id,
          PieceAnnotations(
            pieceId: piece.id,
            layers: const [
              InkLayer(
                ownerId: 'owner-1',
                role: PieceRole.owner,
                strokes: [
                  InkStroke(
                    id: 'precise-stroke',
                    authorId: 'owner-1',
                    pageIndex: 0,
                    colorId: 'red',
                    points: precisePoints,
                  ),
                ],
              ),
            ],
            audioNotes: [
              AudioNote(
                id: 'precise-note',
                authorId: 'owner-1',
                audioAssetId: senderAssetId,
                pageIndex: 0,
                durationMs: 2500,
                region: preciseRegion,
                createdAt: DateTime(2024),
              ),
            ],
          ),
        );

        final exportResult = await senderService.exportBundle(piece.id);
        final bundle = (exportResult as Success<ExportedBundle>).value;

        final receiverAnnotations = _FakeAnnotationRepository();
        final receiverService = FileShareReviewSyncService(
          pieceRepository: _FakePieceRepository(piece),
          annotationRepository: receiverAnnotations,
          audioAssetStore: _FakeAudioAssetStore(
            receiverAudioDir,
            label: 'receiver-asset',
          ),
          storage: storage,
          currentUserId: () => 'collaborator-1',
          bundlesDirectory: () async => tempDir,
        );

        await receiverService.importBundle(bundle.filePath);

        final receiverState = await receiverAnnotations.watch(piece.id).first;
        final importedStroke = receiverState.layers.single.strokes.single;
        expect(importedStroke.points, precisePoints);
        final importedNote = receiverState.audioNotes.single;
        expect(importedNote.region, preciseRegion);
      },
    );

    test(
      "importBundle never touches the receiver's own existing layer or "
      "audio notes when applying the other author's slice",
      () async {
        final exportResult = await senderService.exportBundle(piece.id);
        final bundle = (exportResult as Success<ExportedBundle>).value;

        // The receiver (collaborator) already has their own annotations
        // before importing the owner's bundle.
        final receiverAnnotations = _FakeAnnotationRepository()
          ..seed(
            piece.id,
            PieceAnnotations(
              pieceId: piece.id,
              layers: const [
                InkLayer(
                  ownerId: 'collaborator-1',
                  role: PieceRole.collaborator,
                  strokes: [
                    InkStroke(
                      id: 'collaborators-own-stroke',
                      authorId: 'collaborator-1',
                      pageIndex: 0,
                      colorId: 'blue',
                      points: [InkPoint(x: 0.5, y: 0.5)],
                    ),
                  ],
                ),
              ],
              audioNotes: [
                AudioNote(
                  id: 'collaborators-own-note',
                  authorId: 'collaborator-1',
                  audioAssetId: 'collaborator-asset-0',
                  pageIndex: 0,
                  durationMs: 1500,
                  region: const Region(
                    pageIndex: 0,
                    left: 0.4,
                    top: 0.4,
                    width: 0.1,
                    height: 0.1,
                  ),
                  createdAt: DateTime(2024),
                ),
              ],
            ),
          );
        final receiverService = FileShareReviewSyncService(
          pieceRepository: _FakePieceRepository(piece),
          annotationRepository: receiverAnnotations,
          audioAssetStore: _FakeAudioAssetStore(
            receiverAudioDir,
            label: 'receiver-asset',
          ),
          storage: storage,
          currentUserId: () => 'collaborator-1',
          bundlesDirectory: () async => tempDir,
        );

        await receiverService.importBundle(bundle.filePath);

        final receiverState = await receiverAnnotations.watch(piece.id).first;
        // The collaborator's own layer/notes are untouched, sitting
        // alongside the freshly-imported owner layer.
        final collaboratorLayer = receiverState.layers.firstWhere(
          (l) => l.ownerId == 'collaborator-1',
        );
        expect(collaboratorLayer.strokes.map((s) => s.id), [
          'collaborators-own-stroke',
        ]);
        expect(
          receiverState.audioNotes.map((n) => n.id),
          contains('collaborators-own-note'),
        );
        final ownerLayer = receiverState.layers.firstWhere(
          (l) => l.ownerId == 'owner-1',
        );
        expect(ownerLayer.strokes.map((s) => s.id).toSet(), {'s1', 's2'});
      },
    );

    test(
      'importBundle drops a bundle whose exportedAt is not newer than the '
      'last-applied revision',
      () async {
        final firstExport = await senderService.exportBundle(piece.id);
        final firstBundle = (firstExport as Success<ExportedBundle>).value;

        final receiverAnnotations = _FakeAnnotationRepository();
        final receiverService = FileShareReviewSyncService(
          pieceRepository: _FakePieceRepository(piece),
          annotationRepository: receiverAnnotations,
          audioAssetStore: _FakeAudioAssetStore(
            receiverAudioDir,
            label: 'receiver-asset',
          ),
          storage: storage,
          currentUserId: () => 'collaborator-1',
          bundlesDirectory: () async => tempDir,
        );

        final firstImport = await receiverService.importBundle(
          firstBundle.filePath,
        );
        expect(
          (firstImport as Success<ReviewBundleSummary>).value.strokeCount,
          2,
        );

        // Simulate an older bundle (e.g. delivered out of order) by seeding
        // the sender with fewer strokes than were already applied, then
        // exporting with an explicit, earlier clock.
        final staleSenderAnnotations = _FakeAnnotationRepository()
          ..seed(
            piece.id,
            PieceAnnotations(
              pieceId: piece.id,
              layers: [
                InkLayer(
                  ownerId: 'owner-1',
                  role: PieceRole.owner,
                  strokes: [stroke('only-one')],
                ),
              ],
              audioNotes: const [],
            ),
          );
        final staleSenderService = FileShareReviewSyncService(
          pieceRepository: _FakePieceRepository(piece),
          annotationRepository: staleSenderAnnotations,
          audioAssetStore: senderAudioStore,
          storage: LocalStorageService(await SharedPreferences.getInstance()),
          currentUserId: () => 'owner-1',
          bundlesDirectory: () async => tempDir,
          clock: () => DateTime(2020), // deliberately before the first export
        );
        final staleExport = await staleSenderService.exportBundle(piece.id);
        final staleBundle = (staleExport as Success<ExportedBundle>).value;

        final staleImport = await receiverService.importBundle(
          staleBundle.filePath,
        );

        expect(staleImport, isA<Success<ReviewBundleSummary>>());
        final staleSummary =
            (staleImport as Success<ReviewBundleSummary>).value;
        expect(staleSummary.strokeCount, 0);
        expect(staleSummary.audioNoteCount, 0);

        // The receiver's state is unchanged: still the *first* import's two
        // strokes, not the stale one-stroke bundle.
        final receiverState = await receiverAnnotations.watch(piece.id).first;
        expect(
          receiverState.layers.single.strokes.map((s) => s.id).toSet(),
          {'s1', 's2'},
        );
      },
    );

    test(
      'importBundle invokes the notification hook only when content '
      'actually changed',
      () async {
        final export = await senderService.exportBundle(piece.id);
        final bundle = (export as Success<ExportedBundle>).value;

        var notifyCalls = 0;
        final receiverAnnotations = _FakeAnnotationRepository();
        final receiverService = FileShareReviewSyncService(
          pieceRepository: _FakePieceRepository(piece),
          annotationRepository: receiverAnnotations,
          audioAssetStore: _FakeAudioAssetStore(
            receiverAudioDir,
            label: 'receiver-asset',
          ),
          storage: storage,
          currentUserId: () => 'collaborator-1',
          bundlesDirectory: () async => tempDir,
          onImported: ({required title, required body}) async {
            notifyCalls++;
          },
        );

        await receiverService.importBundle(bundle.filePath);
        expect(notifyCalls, 1);

        // Re-importing the same (now-stale) bundle must not notify again.
        await receiverService.importBundle(bundle.filePath);
        expect(notifyCalls, 1);
      },
    );

    test(
      "importBundle's notification title includes the author's name from "
      'the manifest when known',
      () async {
        final namedSenderService = FileShareReviewSyncService(
          pieceRepository: _FakePieceRepository(piece),
          annotationRepository: senderAnnotations,
          audioAssetStore: senderAudioStore,
          storage: storage,
          currentUserId: () => 'owner-1',
          currentUserName: () => 'Jane Doe',
          bundlesDirectory: () async => tempDir,
        );
        final export = await namedSenderService.exportBundle(piece.id);
        final bundle = (export as Success<ExportedBundle>).value;

        String? capturedTitle;
        String? capturedBody;
        final receiverService = FileShareReviewSyncService(
          pieceRepository: _FakePieceRepository(piece),
          annotationRepository: _FakeAnnotationRepository(),
          audioAssetStore: _FakeAudioAssetStore(
            receiverAudioDir,
            label: 'receiver-asset',
          ),
          storage: storage,
          currentUserId: () => 'collaborator-1',
          bundlesDirectory: () async => tempDir,
          onImported: ({required title, required body}) async {
            capturedTitle = title;
            capturedBody = body;
          },
        );

        await receiverService.importBundle(bundle.filePath);

        expect(capturedTitle, 'New feedback from Jane Doe');
        // The body is name-agnostic (stroke/audio-note counts from the
        // manifest), regardless of whether the author's name is known.
        expect(capturedBody, 'Clair de Lune: 2 strokes, 1 notes');
      },
    );

    test(
      "importBundle's notification title falls back to generic copy when "
      "the author's name is unknown",
      () async {
        final export = await senderService.exportBundle(piece.id);
        final bundle = (export as Success<ExportedBundle>).value;

        String? capturedTitle;
        String? capturedBody;
        final receiverService = FileShareReviewSyncService(
          pieceRepository: _FakePieceRepository(piece),
          annotationRepository: _FakeAnnotationRepository(),
          audioAssetStore: _FakeAudioAssetStore(
            receiverAudioDir,
            label: 'receiver-asset',
          ),
          storage: storage,
          currentUserId: () => 'collaborator-1',
          bundlesDirectory: () async => tempDir,
          onImported: ({required title, required body}) async {
            capturedTitle = title;
            capturedBody = body;
          },
        );

        await receiverService.importBundle(bundle.filePath);

        expect(capturedTitle, 'New review feedback');
        expect(capturedBody, 'Clair de Lune: 2 strokes, 1 notes');
      },
    );

    test('importBundle fails for an unpaired/unknown piece', () async {
      final export = await senderService.exportBundle(piece.id);
      final bundle = (export as Success<ExportedBundle>).value;

      final receiverService = FileShareReviewSyncService(
        pieceRepository: _FakePieceRepository(
          Piece(
            id: 'a-different-piece',
            title: 'Other',
            basePdfChecksum: 'x',
            basePdfPath: '',
            ownerId: 'someone-else',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ),
        annotationRepository: _FakeAnnotationRepository(),
        audioAssetStore: _FakeAudioAssetStore(
          receiverAudioDir,
          label: 'receiver-asset',
        ),
        storage: storage,
        currentUserId: () => 'collaborator-1',
        bundlesDirectory: () async => tempDir,
      );

      final result = await receiverService.importBundle(bundle.filePath);

      expect(result, isA<ResultFailure<ReviewBundleSummary>>());
      expect(
        (result as ResultFailure<ReviewBundleSummary>).error,
        isA<ReviewSyncException>(),
      );
    });

    test(
      'importBundle creates a brand-new local Piece from a first-share '
      "bundle's embedded PDF when the receiver has never seen it before",
      () async {
        final pdfBytes = utf8.encode('%PDF-1.4 real bytes');
        final expectedChecksum = pdfBytes
            .fold<int>(0, (sum, byte) => sum + byte)
            .toString();
        final pdfPath = '${tempDir.path}/base.pdf';
        File(pdfPath).writeAsBytesSync(pdfBytes);
        final pieceWithPdf = Piece(
          id: piece.id,
          title: piece.title,
          basePdfChecksum: expectedChecksum,
          basePdfPath: pdfPath,
          ownerId: piece.ownerId,
          collaborators: piece.collaborators,
          createdAt: piece.createdAt,
          updatedAt: piece.updatedAt,
        );
        final firstShareSenderService = FileShareReviewSyncService(
          pieceRepository: _FakePieceRepository(pieceWithPdf),
          annotationRepository: senderAnnotations,
          audioAssetStore: senderAudioStore,
          storage: storage,
          currentUserId: () => 'owner-1',
          bundlesDirectory: () async => tempDir,
        );

        final exportResult = await firstShareSenderService.exportBundle(
          piece.id,
        );
        final bundle = (exportResult as Success<ExportedBundle>).value;

        // The receiver's device has *never* seen this piece — its
        // repository starts out empty, unlike every other test above.
        final receiverPieceRepository = _FakePieceRepository.withPieces([]);
        final receiverAnnotations = _FakeAnnotationRepository();
        final receiverService = FileShareReviewSyncService(
          pieceRepository: receiverPieceRepository,
          annotationRepository: receiverAnnotations,
          audioAssetStore: _FakeAudioAssetStore(
            receiverAudioDir,
            label: 'receiver-asset',
          ),
          storage: storage,
          currentUserId: () => 'collaborator-1',
          bundlesDirectory: () async => tempDir,
        );

        final importResult = await receiverService.importBundle(
          bundle.filePath,
        );

        expect(importResult, isA<Success<ReviewBundleSummary>>());
        final summary = (importResult as Success<ReviewBundleSummary>).value;
        expect(summary.strokeCount, 2);
        expect(summary.audioNoteCount, 1);

        // A brand-new local Piece was created, preserving the sender's
        // identity fields rather than minting a new id.
        final registered = await receiverPieceRepository.getPiece(piece.id);
        expect(registered, isA<Success<Piece>>());
        final registeredPiece = (registered as Success<Piece>).value;
        expect(registeredPiece.title, piece.title);
        expect(registeredPiece.ownerId, 'owner-1');
        expect(registeredPiece.collaboratorIds, ['collaborator-1']);
        // The extracted PDF's checksum matches the manifest's declared
        // basePdfChecksum — proof the transferred bytes are intact.
        expect(registeredPiece.basePdfChecksum, expectedChecksum);

        final receiverState = await receiverAnnotations.watch(piece.id).first;
        expect(
          receiverState.layers.single.strokes.map((s) => s.id).toSet(),
          {'s1', 's2'},
        );
        expect(receiverState.audioNotes.single.id, 'n1');
      },
    );

    test(
      "importBundle attaches the sender's real ownerName (captured in the "
      "manifest at export time) and the receiver's own collaboratorName to "
      'a brand-new first-share Piece',
      () async {
        final pdfBytes = utf8.encode('%PDF-1.4 real bytes');
        final expectedChecksum = pdfBytes
            .fold<int>(0, (sum, byte) => sum + byte)
            .toString();
        final pdfPath = '${tempDir.path}/base.pdf';
        File(pdfPath).writeAsBytesSync(pdfBytes);
        final pieceWithPdf = Piece(
          id: piece.id,
          title: piece.title,
          basePdfChecksum: expectedChecksum,
          basePdfPath: pdfPath,
          ownerId: piece.ownerId,
          collaborators: piece.collaborators,
          createdAt: piece.createdAt,
          updatedAt: piece.updatedAt,
        );
        final firstShareSenderService = FileShareReviewSyncService(
          pieceRepository: _FakePieceRepository(pieceWithPdf),
          annotationRepository: senderAnnotations,
          audioAssetStore: senderAudioStore,
          storage: storage,
          currentUserId: () => 'owner-1',
          currentUserName: () => 'Jane Doe',
          bundlesDirectory: () async => tempDir,
        );

        final exportResult = await firstShareSenderService.exportBundle(
          piece.id,
        );
        final bundle = (exportResult as Success<ExportedBundle>).value;

        final receiverPieceRepository = _FakePieceRepository.withPieces([]);
        final receiverService = FileShareReviewSyncService(
          pieceRepository: receiverPieceRepository,
          annotationRepository: _FakeAnnotationRepository(),
          audioAssetStore: _FakeAudioAssetStore(
            receiverAudioDir,
            label: 'receiver-asset',
          ),
          storage: storage,
          currentUserId: () => 'collaborator-1',
          currentUserName: () => 'Sam Smith',
          bundlesDirectory: () async => tempDir,
        );

        await receiverService.importBundle(bundle.filePath);

        final registered = await receiverPieceRepository.getPiece(piece.id);
        final registeredPiece = (registered as Success<Piece>).value;
        expect(registeredPiece.ownerName, 'Jane Doe');
        expect(registeredPiece.collaborators.single.name, 'Sam Smith');
      },
    );

    test(
      "importBundle hard-fails when the local piece's basePdfChecksum has "
      "drifted from the sender's, rather than silently applying possibly "
      'misaligned region-anchored annotations',
      () async {
        final exportResult = await senderService.exportBundle(piece.id);
        final bundle = (exportResult as Success<ExportedBundle>).value;

        final driftedPiece = Piece(
          id: piece.id,
          title: piece.title,
          basePdfChecksum: 'a-completely-different-checksum',
          basePdfPath: piece.basePdfPath,
          ownerId: piece.ownerId,
          collaborators: piece.collaborators,
          createdAt: piece.createdAt,
          updatedAt: piece.updatedAt,
        );
        final receiverAnnotations = _FakeAnnotationRepository();
        final receiverService = FileShareReviewSyncService(
          pieceRepository: _FakePieceRepository(driftedPiece),
          annotationRepository: receiverAnnotations,
          audioAssetStore: _FakeAudioAssetStore(
            receiverAudioDir,
            label: 'receiver-asset',
          ),
          storage: storage,
          currentUserId: () => 'collaborator-1',
          bundlesDirectory: () async => tempDir,
        );

        final result = await receiverService.importBundle(bundle.filePath);

        expect(result, isA<ResultFailure<ReviewBundleSummary>>());
        expect(
          (result as ResultFailure<ReviewBundleSummary>).error,
          isA<ReviewSyncException>(),
        );
        // No annotations were applied — the mismatch was caught before any
        // (possibly misaligned) strokes/notes landed.
        final receiverState = await receiverAnnotations.watch(piece.id).first;
        expect(receiverState.layers, isEmpty);
        expect(receiverState.audioNotes, isEmpty);
      },
    );
  });
}
