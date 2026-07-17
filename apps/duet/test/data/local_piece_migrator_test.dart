import 'package:core_utils/core_utils.dart';
import 'package:duet/data/local_piece_migrator.dart';
import 'package:duet/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records a `replaceAuthorSlice` call for assertion.
class _SliceWrite {
  _SliceWrite(this.pieceId, this.authorId, this.role, this.strokes, this.notes);
  final String pieceId;
  final String authorId;
  final PieceRole role;
  final List<InkStroke> strokes;
  final List<AudioNote> notes;
}

/// A fake [PieceRepository] the migrator writes to (cloud side). Records the
/// pieces it creates; [getPiece] reflects them so a resume reuses the doc.
class _FakePieceRepository implements PieceRepository {
  final List<String> registered = <String>[];
  final Map<String, Piece> _created = <String, Piece>{};

  @override
  Future<Result<Piece>> getPiece(String pieceId) async {
    final piece = _created[pieceId];
    if (piece == null) {
      return ResultFailure<Piece>(StateError('Unknown piece: $pieceId'));
    }
    return Success<Piece>(piece);
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
    registered.add(pieceId);
    final now = DateTime(2026, 7, 13);
    final piece = Piece(
      id: pieceId,
      title: title,
      basePdfChecksum: 'chk-$pieceId',
      basePdfPath: sourcePath,
      ownerId: ownerId,
      ownerName: ownerName,
      createdAt: now,
      updatedAt: now,
    );
    _created[pieceId] = piece;
    return Success<Piece>(piece);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// A fake [AnnotationRepository] doubling as both local source (preset
/// annotations returned by [watch]) and cloud sink (recorded slice writes).
class _FakeAnnotationRepository implements AnnotationRepository {
  final Map<String, PieceAnnotations> preset = <String, PieceAnnotations>{};
  final List<_SliceWrite> slices = <_SliceWrite>[];

  @override
  Stream<PieceAnnotations> watch(String pieceId) =>
      Stream<PieceAnnotations>.value(
        preset[pieceId] ?? PieceAnnotations.empty(pieceId),
      );

  @override
  Future<Result<void>> replaceAuthorSlice(
    String pieceId,
    String authorId, {
    required PieceRole role,
    required List<InkStroke> strokes,
    required List<AudioNote> audioNotes,
  }) async {
    slices.add(_SliceWrite(pieceId, authorId, role, strokes, audioNotes));
    return const Success<void>(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// A fake [AudioAssetStore]: [pathFor] resolves a deterministic local path
/// (source side), [put] mints a fresh cloud asset id and records the source
/// (sink side).
class _FakeAudioAssetStore implements AudioAssetStore {
  final List<String> putSources = <String>[];
  int _seq = 0;

  @override
  Future<Result<String>> pathFor(
    String assetId, {
    required String pieceId,
  }) async => Success<String>('/local/audio/$assetId.m4a');

  @override
  Future<Result<String>> put(
    String sourcePath, {
    required String pieceId,
  }) => Result.guard<String>(() async {
    // Same cap behavior as the real stores (G3, M8.3).
    ensureAudioNoteWithinCap(sourcePath);
    putSources.add(sourcePath);
    return 'cloud-asset-${_seq++}';
  });

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// A fake [PieceBinaryStore]: records uploads and can be made to fail for a
/// given piece id (to exercise partial-resume).
class _FakeBinaryStore implements PieceBinaryStore {
  final List<String> uploaded = <String>[];
  final Set<String> failFor = <String>{};

  @override
  Stream<UploadProgress> uploadBasePdf({
    required String pieceId,
    required String localPath,
    required String checksum,
  }) async* {
    if (failFor.contains(pieceId)) {
      throw StateError('upload failed for $pieceId');
    }
    uploaded.add(pieceId);
    yield const UploadProgress(bytesTransferred: 10, totalBytes: 10);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Piece _piece(
  String id, {
  String owner = 'mock-owner',
  List<Collaborator> collaborators = const <Collaborator>[],
}) {
  final now = DateTime(2026);
  return Piece(
    id: id,
    title: 'Title $id',
    basePdfChecksum: 'chk-$id',
    basePdfPath: '/local/$id.pdf',
    ownerId: owner,
    ownerName: 'Olivia',
    collaborators: collaborators,
    createdAt: now,
    updatedAt: now,
  );
}

InkStroke _stroke(String id, String author) => InkStroke(
  id: id,
  authorId: author,
  pageIndex: 0,
  colorId: 'ink',
  points: const <InkPoint>[InkPoint(x: 0.1, y: 0.1)],
);

AudioNote _note(String id, String author, String assetId) => AudioNote(
  id: id,
  authorId: author,
  audioAssetId: assetId,
  pageIndex: 0,
  durationMs: 1000,
  region: const Region(
    pageIndex: 0,
    left: 0.1,
    top: 0.1,
    width: 0.1,
    height: 0.1,
  ),
  createdAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalPieceMigrator', () {
    late LocalStorageService storage;
    late _FakePieceRepository cloudPieces;
    late _FakeAnnotationRepository localAnnotations;
    late _FakeAnnotationRepository cloudAnnotations;
    late _FakeAudioAssetStore localAudio;
    late _FakeAudioAssetStore cloudAudio;
    late _FakeBinaryStore binaryStore;
    late List<Piece> localPieces;

    const uid = 'real-uid';

    LocalPieceMigrator migrator() => LocalPieceMigrator(
      readLocalPieces: () async => localPieces,
      localAnnotations: localAnnotations,
      localAudio: localAudio,
      cloudPieces: cloudPieces,
      cloudAnnotations: cloudAnnotations,
      cloudAudio: cloudAudio,
      binaryStore: binaryStore,
      storage: storage,
      currentUserId: () => uid,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      storage = LocalStorageService(await SharedPreferences.getInstance());
      cloudPieces = _FakePieceRepository();
      localAnnotations = _FakeAnnotationRepository();
      cloudAnnotations = _FakeAnnotationRepository();
      localAudio = _FakeAudioAssetStore();
      cloudAudio = _FakeAudioAssetStore();
      binaryStore = _FakeBinaryStore();
      localPieces = <Piece>[];
    });

    test(
      'migrates a piece: re-owns it, uploads PDF, writes owner slice',
      () async {
        localPieces = [
          _piece('p1', collaborators: const [Collaborator(uid: 'mock-friend')]),
        ];
        localAnnotations.preset['p1'] = PieceAnnotations(
          pieceId: 'p1',
          layers: [
            InkLayer(
              ownerId: 'mock-owner',
              role: PieceRole.owner,
              strokes: [_stroke('s1', 'mock-owner')],
            ),
          ],
          audioNotes: [_note('n1', 'mock-owner', 'local-asset-1')],
        );

        final result = await migrator().migrate();

        expect(result, const MigrationResult(migrated: 1, failed: 0));
        // Re-owned to the signed-in uid, collaborators dropped.
        expect(cloudPieces.registered, ['p1']);
        final created = (await cloudPieces.getPiece('p1')).orThrow();
        expect(created.ownerId, uid);
        // Base PDF uploaded.
        expect(binaryStore.uploaded, ['p1']);
        // Audio migrated (owner's note) — source resolved from the local store.
        expect(cloudAudio.putSources, ['/local/audio/local-asset-1.m4a']);
        // The owner slice is written under the new uid with re-keyed content.
        expect(cloudAnnotations.slices, hasLength(1));
        final slice = cloudAnnotations.slices.single;
        expect(slice.authorId, uid);
        expect(slice.role, PieceRole.owner);
        expect(slice.strokes.single.authorId, uid);
        expect(slice.notes.single.authorId, uid);
        expect(slice.notes.single.audioAssetId, 'cloud-asset-0');
      },
    );

    test('only the owner slice migrates; other authors are dropped', () async {
      localPieces = [_piece('p1')];
      localAnnotations.preset['p1'] = PieceAnnotations(
        pieceId: 'p1',
        layers: [
          InkLayer(
            ownerId: 'mock-owner',
            role: PieceRole.owner,
            strokes: [_stroke('s1', 'mock-owner')],
          ),
          InkLayer(
            ownerId: 'mock-friend',
            role: PieceRole.collaborator,
            strokes: [_stroke('s2', 'mock-friend')],
          ),
        ],
        audioNotes: [
          _note('n1', 'mock-owner', 'local-asset-1'),
          _note('n2', 'mock-friend', 'local-asset-2'),
        ],
      );

      await migrator().migrate();

      final slice = cloudAnnotations.slices.single;
      expect(slice.strokes.map((s) => s.id), ['s1']); // s2 dropped
      expect(slice.notes.map((n) => n.id), ['n1']); // n2 dropped
      expect(cloudAudio.putSources, ['/local/audio/local-asset-1.m4a']);
    });

    test(
      'a piece with no annotations migrates without a slice write',
      () async {
        localPieces = [_piece('p1')];

        final result = await migrator().migrate();

        expect(result, const MigrationResult(migrated: 1, failed: 0));
        expect(binaryStore.uploaded, ['p1']);
        expect(cloudAnnotations.slices, isEmpty); // nothing to write
      },
    );

    test('already-migrated pieces are skipped on a second run', () async {
      localPieces = [_piece('p1')];

      final first = await migrator().migrate();
      final second = await migrator().migrate();

      expect(first, const MigrationResult(migrated: 1, failed: 0));
      expect(second, const MigrationResult(migrated: 0, failed: 0));
      expect(cloudPieces.registered, ['p1']); // not re-registered
    });

    test('a failed upload leaves the piece for a resumable retry', () async {
      localPieces = [_piece('p1'), _piece('p2')];
      binaryStore.failFor.add('p2');

      final first = await migrator().migrate();
      expect(first, const MigrationResult(migrated: 1, failed: 1));
      expect(binaryStore.uploaded, ['p1']);
      // p2's doc was created before its upload failed.
      expect(cloudPieces.registered, ['p1', 'p2']);

      // Reconnect: p2 uploads on the next pass, reusing its existing doc.
      binaryStore.failFor.clear();
      final second = await migrator().migrate();

      expect(second, const MigrationResult(migrated: 1, failed: 0));
      expect(binaryStore.uploaded, ['p1', 'p2']);
      expect(cloudPieces.registered, ['p1', 'p2']); // p2 not re-registered
    });

    test('pendingCount reflects not-yet-migrated pieces', () async {
      localPieces = [_piece('p1'), _piece('p2')];

      expect(await migrator().pendingCount(), 2);
      binaryStore.failFor.add('p2');
      await migrator().migrate();
      expect(await migrator().pendingCount(), 1); // p2 still pending
    });
  });
}
