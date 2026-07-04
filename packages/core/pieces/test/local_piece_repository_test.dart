import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePdfRenderService implements PdfRenderService {
  @override
  Future<Result<String>> checksum(String path) async =>
      Success('checksum-of-${path.split('/').last}');

  @override
  Future<Result<int>> open(String path) => throw UnimplementedError();

  @override
  Future<Result<PdfPageImage>> renderPage(int pageIndex, {double scale = 1}) =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalPieceRepository', () {
    late Directory tempDir;
    late File sourcePdf;
    late LocalStorageService storage;
    late LocalAnnotationRepository annotationRepository;
    late LocalAudioAssetStore audioAssetStore;
    late LocalPieceRepository repository;
    late String currentUserId;

    Future<Directory> documentsDirectory() async => tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pieces_test');
      sourcePdf = File('${tempDir.path}/source.pdf')
        ..writeAsStringSync('%PDF-1.4 fake');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      currentUserId = 'teacher-1';

      audioAssetStore = LocalAudioAssetStore(
        documentsDirectory: documentsDirectory,
      );
      late LocalPieceRepository pieceRepositoryRef;
      annotationRepository = LocalAnnotationRepository(
        storage: storage,
        currentUserId: () => currentUserId,
        pieceRepository: _DeferredPieceRepository(() => pieceRepositoryRef),
      );
      repository = LocalPieceRepository(
        storage: storage,
        currentUserId: () => currentUserId,
        pdfRenderService: _FakePdfRenderService(),
        annotationRepository: () => annotationRepository,
        audioAssetStore: audioAssetStore,
        documentsDirectory: documentsDirectory,
      );
      pieceRepositoryRef = repository;
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('importPiece copies the PDF and computes a checksum', () async {
      final result = await repository.importPiece(
        title: 'Clair de Lune',
        sourcePath: sourcePdf.path,
      );

      expect(result, isA<Success<Piece>>());
      final piece = (result as Success<Piece>).value;
      expect(piece.title, 'Clair de Lune');
      expect(piece.teacherId, currentUserId);
      expect(piece.basePdfChecksum, 'checksum-of-source.pdf');
      expect(File(piece.basePdfPath).existsSync(), isTrue);
      expect(piece.basePdfPath, isNot(sourcePdf.path));
    });

    test(
      "importPiece never modifies the original source file's bytes",
      () async {
        final originalBytes = sourcePdf.readAsBytesSync();

        final result = await repository.importPiece(
          title: 'Clair de Lune',
          sourcePath: sourcePdf.path,
        );
        final piece = (result as Success<Piece>).value;

        // The source file at its original path is untouched...
        expect(sourcePdf.readAsBytesSync(), originalBytes);
        // ...and the piece's own copy is a byte-for-byte duplicate, not a
        // reference to the same file re-checksummed.
        expect(File(piece.basePdfPath).readAsBytesSync(), originalBytes);
      },
    );

    test('getPiece fails for an unknown id', () async {
      final result = await repository.getPiece('missing');
      expect(result, isA<ResultFailure<Piece>>());
    });

    test(
      'watchPieces scopes to the current user as teacher or student',
      () async {
        final imported = await repository.importPiece(
          title: 'Reverie',
          sourcePath: sourcePdf.path,
        );
        final piece = (imported as Success<Piece>).value;

        final asTeacher = await repository.watchPieces().first;
        expect(asTeacher.map((p) => p.id), contains(piece.id));

        currentUserId = 'unrelated-user';
        final asUnrelated = await repository.watchPieces().first;
        expect(asUnrelated.map((p) => p.id), isNot(contains(piece.id)));
      },
    );

    test('watchPieces emits an update after a mutation', () async {
      final emissions = <int>[];
      final subscription = repository.watchPieces().listen(
        (pieces) => emissions.add(pieces.length),
      );
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(emissions, [0]);

      await repository.importPiece(
        title: 'Nocturne',
        sourcePath: sourcePdf.path,
      );
      await pumpEventQueue();

      expect(emissions, [0, 1]);
    });

    test('renamePiece updates the title', () async {
      final imported = await repository.importPiece(
        title: 'Old title',
        sourcePath: sourcePdf.path,
      );
      final piece = (imported as Success<Piece>).value;

      final renameResult = await repository.renamePiece(piece.id, 'New title');
      expect(renameResult, isA<Success<void>>());

      final fetched = await repository.getPiece(piece.id);
      expect((fetched as Success<Piece>).value.title, 'New title');
    });

    test(
      'deletePiece removes the piece, its annotations and its audio assets',
      () async {
        final imported = await repository.importPiece(
          title: 'To delete',
          sourcePath: sourcePdf.path,
        );
        final piece = (imported as Success<Piece>).value;

        await annotationRepository.addStroke(
          piece.id,
          InkStroke(
            id: 's1',
            authorId: currentUserId,
            pageIndex: 0,
            colorId: 'red',
            points: const [InkPoint(x: 0, y: 0)],
          ),
        );
        final audioFile = File('${tempDir.path}/note.m4a')
          ..writeAsStringSync('fake audio');
        final assetResult = await audioAssetStore.put(audioFile.path);
        final assetId = (assetResult as Success<String>).value;
        await annotationRepository.addAudioNote(
          piece.id,
          AudioNote(
            id: 'n1',
            authorId: currentUserId,
            audioAssetId: assetId,
            pageIndex: 0,
            durationMs: 1000,
            region: const Region(
              pageIndex: 0,
              left: 0,
              top: 0,
              width: 0.1,
              height: 0.1,
            ),
            createdAt: DateTime(2024),
          ),
        );

        final deleteResult = await repository.deletePiece(piece.id);
        expect(deleteResult, isA<Success<void>>());

        expect(
          await repository.getPiece(piece.id),
          isA<ResultFailure<Piece>>(),
        );
        final remainingAnnotations = await annotationRepository
            .watch(piece.id)
            .first;
        expect(remainingAnnotations.layers, isEmpty);
        expect(remainingAnnotations.audioNotes, isEmpty);
        expect(
          await audioAssetStore.pathFor(assetId),
          isA<ResultFailure<String>>(),
        );
      },
    );

    test('pairStudent attaches a student to an unpaired piece', () async {
      final imported = await repository.importPiece(
        title: 'To pair',
        sourcePath: sourcePdf.path,
      );
      final piece = (imported as Success<Piece>).value;

      final result = await repository.pairStudent(
        piece.id,
        studentId: 'student-1',
      );
      expect(result, isA<Success<Piece>>());
      expect((result as Success<Piece>).value.studentId, 'student-1');

      final fetched = await repository.getPiece(piece.id);
      expect((fetched as Success<Piece>).value.studentId, 'student-1');
    });

    test(
      'pairStudent fails when the piece already has a different student',
      () async {
        final imported = await repository.importPiece(
          title: 'Already paired',
          sourcePath: sourcePdf.path,
        );
        final piece = (imported as Success<Piece>).value;
        await repository.pairStudent(piece.id, studentId: 'student-1');

        final result = await repository.pairStudent(
          piece.id,
          studentId: 'student-2',
        );

        expect(result, isA<ResultFailure<Piece>>());
      },
    );

    test('pairStudent is idempotent for the same student', () async {
      final imported = await repository.importPiece(
        title: 'Re-pair same student',
        sourcePath: sourcePdf.path,
      );
      final piece = (imported as Success<Piece>).value;
      await repository.pairStudent(piece.id, studentId: 'student-1');

      final result = await repository.pairStudent(
        piece.id,
        studentId: 'student-1',
      );

      expect(result, isA<Success<Piece>>());
      expect((result as Success<Piece>).value.studentId, 'student-1');
    });

    test('the teacher cannot leave their own piece', () async {
      final imported = await repository.importPiece(
        title: 'Paired piece',
        sourcePath: sourcePdf.path,
      );
      final piece = (imported as Success<Piece>).value;

      currentUserId = piece.teacherId;
      final teacherLeave = await repository.leavePiece(piece.id);
      expect(teacherLeave, isA<ResultFailure<void>>());
    });

    test('a paired student leaving clears their association only', () async {
      // Pairing itself is owned by `feature_pairing`, not this package, so
      // seed a paired piece directly via the storage a fresh repository
      // reads on construction, rather than going through a pairing API.
      final now = DateTime(2024).toIso8601String();
      await storage.setString(
        'pieces.records',
        '[{"id":"p1","title":"Paired","basePdfChecksum":"abc",'
            '"basePdfPath":"${sourcePdf.path}","teacherId":"teacher-1",'
            '"studentId":"student-1","createdAt":"$now","updatedAt":"$now"}]',
      );
      late LocalPieceRepository seededRepository;
      final seededAnnotations = LocalAnnotationRepository(
        storage: storage,
        currentUserId: () => currentUserId,
        pieceRepository: _DeferredPieceRepository(() => seededRepository),
      );
      seededRepository = LocalPieceRepository(
        storage: storage,
        currentUserId: () => currentUserId,
        pdfRenderService: _FakePdfRenderService(),
        annotationRepository: () => seededAnnotations,
        audioAssetStore: audioAssetStore,
        documentsDirectory: documentsDirectory,
      );

      currentUserId = 'student-1';
      final leaveResult = await seededRepository.leavePiece('p1');
      expect(leaveResult, isA<Success<void>>());

      final asStudent = await seededRepository.watchPieces().first;
      expect(asStudent, isEmpty);

      currentUserId = 'teacher-1';
      final asTeacher = await seededRepository.watchPieces().first;
      expect(asTeacher.single.id, 'p1');
      expect(asTeacher.single.studentId, isNull);
    });
  });

  test(
    'a fresh repository over the same storage resolves persisted pieces',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('pieces_restart');
      addTearDown(() => tempDir.delete(recursive: true));
      final sourcePdf = File('${tempDir.path}/source.pdf')
        ..writeAsStringSync('%PDF-1.4 fake');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      late LocalPieceRepository firstRepository;
      final firstAnnotations = LocalAnnotationRepository(
        storage: storage,
        currentUserId: () => 'teacher-1',
        pieceRepository: _DeferredPieceRepository(() => firstRepository),
      );
      firstRepository = LocalPieceRepository(
        storage: storage,
        currentUserId: () => 'teacher-1',
        pdfRenderService: _FakePdfRenderService(),
        annotationRepository: () => firstAnnotations,
        audioAssetStore: LocalAudioAssetStore(
          documentsDirectory: () async => tempDir,
        ),
        documentsDirectory: () async => tempDir,
      );

      final imported = await firstRepository.importPiece(
        title: 'Persisted piece',
        sourcePath: sourcePdf.path,
      );
      final piece = (imported as Success<Piece>).value;

      late LocalPieceRepository secondRepository;
      final secondAnnotations = LocalAnnotationRepository(
        storage: storage,
        currentUserId: () => 'teacher-1',
        pieceRepository: _DeferredPieceRepository(() => secondRepository),
      );
      secondRepository = LocalPieceRepository(
        storage: storage,
        currentUserId: () => 'teacher-1',
        pdfRenderService: _FakePdfRenderService(),
        annotationRepository: () => secondAnnotations,
        audioAssetStore: LocalAudioAssetStore(
          documentsDirectory: () async => tempDir,
        ),
        documentsDirectory: () async => tempDir,
      );

      final result = await secondRepository.getPiece(piece.id);
      expect(result, isA<Success<Piece>>());
      expect((result as Success<Piece>).value.title, 'Persisted piece');
    },
  );
}

/// Resolves a [PieceRepository] lazily, deferring to the resolver callback
/// on each call rather than capturing an instance at construction time —
/// breaks the constructor cycle between `LocalPieceRepository` and
/// `LocalAnnotationRepository` in tests, mirroring the lazy-provider wiring
/// `LocalPieceRepository` itself uses for its `AnnotationRepository`
/// dependency.
class _DeferredPieceRepository implements PieceRepository {
  _DeferredPieceRepository(this._resolve);

  final PieceRepository Function() _resolve;

  @override
  Future<Result<void>> deletePiece(String pieceId) =>
      _resolve().deletePiece(pieceId);

  @override
  Future<Result<Piece>> getPiece(String pieceId) =>
      _resolve().getPiece(pieceId);

  @override
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
  }) => _resolve().importPiece(title: title, sourcePath: sourcePath);

  @override
  Future<Result<void>> leavePiece(String pieceId) =>
      _resolve().leavePiece(pieceId);

  @override
  Future<Result<void>> renamePiece(String pieceId, String title) =>
      _resolve().renamePiece(pieceId, title);

  @override
  Future<Result<Piece>> pairStudent(
    String pieceId, {
    required String studentId,
  }) => _resolve().pairStudent(pieceId, studentId: studentId);

  @override
  Stream<List<Piece>> watchPieces() => _resolve().watchPieces();
}
