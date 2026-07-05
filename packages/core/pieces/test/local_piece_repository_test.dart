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

    test('importPiece stores the given teacherName', () async {
      final result = await repository.importPiece(
        title: 'Clair de Lune',
        sourcePath: sourcePdf.path,
        teacherName: 'Jane Doe',
      );

      expect(result, isA<Success<Piece>>());
      final piece = (result as Success<Piece>).value;
      expect(piece.teacherName, 'Jane Doe');
      expect(piece.studentName, isNull);
    });

    test('importPiece leaves teacherName null when not given one', () async {
      final result = await repository.importPiece(
        title: 'Clair de Lune',
        sourcePath: sourcePdf.path,
      );

      expect((result as Success<Piece>).value.teacherName, isNull);
    });

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

    test(
      'registerImportedPiece creates a piece preserving the given identity '
      'fields rather than minting a new id',
      () async {
        final result = await repository.registerImportedPiece(
          pieceId: 'sender-piece-1',
          title: 'Shared from another device',
          teacherId: 'remote-teacher',
          studentId: 'remote-student',
          teacherName: 'Remote Teacher Name',
          studentName: 'Remote Student Name',
          sourcePath: sourcePdf.path,
        );

        expect(result, isA<Success<Piece>>());
        final piece = (result as Success<Piece>).value;
        expect(piece.id, 'sender-piece-1');
        expect(piece.title, 'Shared from another device');
        expect(piece.teacherId, 'remote-teacher');
        expect(piece.studentId, 'remote-student');
        expect(piece.teacherName, 'Remote Teacher Name');
        expect(piece.studentName, 'Remote Student Name');
        expect(piece.basePdfChecksum, 'checksum-of-source.pdf');
        expect(File(piece.basePdfPath).existsSync(), isTrue);

        final fetched = await repository.getPiece('sender-piece-1');
        expect((fetched as Success<Piece>).value.id, 'sender-piece-1');
      },
    );

    test(
      'registerImportedPiece fails when the piece already exists locally',
      () async {
        await repository.registerImportedPiece(
          pieceId: 'sender-piece-2',
          title: 'First register',
          teacherId: 'remote-teacher',
          sourcePath: sourcePdf.path,
        );

        final result = await repository.registerImportedPiece(
          pieceId: 'sender-piece-2',
          title: 'Second register',
          teacherId: 'remote-teacher',
          sourcePath: sourcePdf.path,
        );

        expect(result, isA<ResultFailure<Piece>>());
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

    test('pairStudent stores the given studentName', () async {
      final imported = await repository.importPiece(
        title: 'To pair',
        sourcePath: sourcePdf.path,
      );
      final piece = (imported as Success<Piece>).value;

      final result = await repository.pairStudent(
        piece.id,
        studentId: 'student-1',
        studentName: 'Sam Smith',
      );

      expect((result as Success<Piece>).value.studentName, 'Sam Smith');
      final fetched = await repository.getPiece(piece.id);
      expect((fetched as Success<Piece>).value.studentName, 'Sam Smith');
    });

    test('pairStudent stores the given studentEmail (AC-2)', () async {
      final imported = await repository.importPiece(
        title: 'To pair',
        sourcePath: sourcePdf.path,
      );
      final piece = (imported as Success<Piece>).value;

      final result = await repository.pairStudent(
        piece.id,
        studentId: 'student-1',
        studentName: 'Sam Smith',
        studentEmail: 'sam@example.com',
      );

      expect(
        (result as Success<Piece>).value.collaborators.single.email,
        'sam@example.com',
      );
    });

    test(
      'pairStudent backfills teacherName only when the piece has none yet',
      () async {
        final imported = await repository.importPiece(
          title: 'To pair',
          sourcePath: sourcePdf.path,
          teacherName: 'Original Teacher Name',
        );
        final piece = (imported as Success<Piece>).value;

        final result = await repository.pairStudent(
          piece.id,
          studentId: 'student-1',
          teacherName: 'A different name',
        );

        // The piece already had a teacherName from importPiece, so the
        // backfill argument must not clobber it — `teacherName` only ever
        // fills a gap, it never overwrites an existing value.
        expect(
          (result as Success<Piece>).value.teacherName,
          'Original Teacher Name',
        );
      },
    );

    test(
      'pairStudent appends a second collaborator rather than rejecting '
      '(FIX-6: no longer "already paired with a different student")',
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

        expect(result, isA<Success<Piece>>());
        expect((result as Success<Piece>).value.collaboratorIds, [
          'student-1',
          'student-2',
        ]);
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

    test(
      'addCollaborator supports a paid piece having two collaborators '
      '(AC-4; not cap-gated at this layer)',
      () async {
        final imported = await repository.importPiece(
          title: 'Duet piece',
          sourcePath: sourcePdf.path,
        );
        final piece = (imported as Success<Piece>).value;

        final first = await repository.addCollaborator(
          piece.id,
          userId: 'student-1',
          name: 'Sam',
        );
        final second = await repository.addCollaborator(
          piece.id,
          userId: 'student-2',
          name: 'Alex',
        );

        expect(first, isA<Success<void>>());
        expect(second, isA<Success<void>>());
        final fetched = await repository.getPiece(piece.id);
        expect((fetched as Success<Piece>).value.collaboratorIds, [
          'student-1',
          'student-2',
        ]);
        expect(fetched.value.collaboratorCount, 2);
      },
    );

    test('addCollaborator is idempotent for the same userId', () async {
      final imported = await repository.importPiece(
        title: 'To pair',
        sourcePath: sourcePdf.path,
      );
      final piece = (imported as Success<Piece>).value;

      await repository.addCollaborator(piece.id, userId: 'student-1');
      final result = await repository.addCollaborator(
        piece.id,
        userId: 'student-1',
        name: 'Sam',
      );

      expect(result, isA<Success<void>>());
      final fetched = await repository.getPiece(piece.id);
      expect((fetched as Success<Piece>).value.collaboratorIds, [
        'student-1',
      ]);
      expect(fetched.value.studentName, 'Sam');
    });

    test(
      "removeCollaborator by the owner detaches only that collaborator's "
      'layer (AC-7)',
      () async {
        final imported = await repository.importPiece(
          title: 'Duet piece',
          sourcePath: sourcePdf.path,
        );
        final piece = (imported as Success<Piece>).value;
        await repository.addCollaborator(piece.id, userId: 'student-1');
        await repository.addCollaborator(piece.id, userId: 'student-2');
        currentUserId = 'student-1';
        await annotationRepository.addStroke(
          piece.id,
          const InkStroke(
            id: 's1',
            authorId: 'student-1',
            pageIndex: 0,
            colorId: 'red',
            points: [InkPoint(x: 0, y: 0)],
          ),
        );
        currentUserId = 'student-2';
        await annotationRepository.addStroke(
          piece.id,
          const InkStroke(
            id: 's2',
            authorId: 'student-2',
            pageIndex: 0,
            colorId: 'blue',
            points: [InkPoint(x: 0.1, y: 0.1)],
          ),
        );
        currentUserId = piece.teacherId;

        final result = await repository.removeCollaborator(
          piece.id,
          'student-1',
        );

        expect(result, isA<Success<void>>());
        final fetched = await repository.getPiece(piece.id);
        expect((fetched as Success<Piece>).value.collaboratorIds, [
          'student-2',
        ]);
        final annotations = await annotationRepository.watch(piece.id).first;
        final remainingOwners = annotations.layers
            .map((l) => l.ownerId)
            .toSet();
        expect(remainingOwners, {'student-2'});
      },
    );

    test('removeCollaborator is idempotent when not a collaborator', () async {
      final imported = await repository.importPiece(
        title: 'Unpaired piece',
        sourcePath: sourcePdf.path,
      );
      final piece = (imported as Success<Piece>).value;

      final result = await repository.removeCollaborator(
        piece.id,
        'never-a-collaborator',
      );

      expect(result, isA<Success<void>>());
    });

    test(
      'removeCollaborator by a non-owner fails with OwnershipViolation '
      '(AC-8)',
      () async {
        final imported = await repository.importPiece(
          title: 'Duet piece',
          sourcePath: sourcePdf.path,
        );
        final piece = (imported as Success<Piece>).value;
        await repository.addCollaborator(piece.id, userId: 'student-1');

        currentUserId = 'student-1';
        final result = await repository.removeCollaborator(
          piece.id,
          'student-1',
        );

        expect(result, isA<ResultFailure<void>>());
        expect(
          (result as ResultFailure<void>).error,
          isA<OwnershipViolation>(),
        );
        final fetched = await repository.getPiece(piece.id);
        expect((fetched as Success<Piece>).value.collaboratorIds, [
          'student-1',
        ]);
      },
    );

    test(
      'deletePiece by a non-owner fails with OwnershipViolation (AC-8)',
      () async {
        final imported = await repository.importPiece(
          title: 'Owner-only delete',
          sourcePath: sourcePdf.path,
        );
        final piece = (imported as Success<Piece>).value;
        await repository.addCollaborator(piece.id, userId: 'student-1');

        currentUserId = 'student-1';
        final result = await repository.deletePiece(piece.id);

        expect(result, isA<ResultFailure<void>>());
        expect(
          (result as ResultFailure<void>).error,
          isA<OwnershipViolation>(),
        );
        currentUserId = piece.teacherId;
        expect(await repository.getPiece(piece.id), isA<Success<Piece>>());
      },
    );

    test(
      'leavePiece with multiple collaborators removes only the caller '
      '(AC-9)',
      () async {
        final imported = await repository.importPiece(
          title: 'Duet piece',
          sourcePath: sourcePdf.path,
        );
        final piece = (imported as Success<Piece>).value;
        await repository.addCollaborator(piece.id, userId: 'student-1');
        await repository.addCollaborator(piece.id, userId: 'student-2');

        currentUserId = 'student-1';
        final result = await repository.leavePiece(piece.id);

        expect(result, isA<Success<void>>());
        currentUserId = piece.teacherId;
        final fetched = await repository.getPiece(piece.id);
        expect((fetched as Success<Piece>).value.collaboratorIds, [
          'student-2',
        ]);
      },
    );

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
  Future<Result<void>> addCollaborator(
    String pieceId, {
    required String userId,
    String? name,
    String? email,
  }) => _resolve().addCollaborator(
    pieceId,
    userId: userId,
    name: name,
    email: email,
  );

  @override
  Future<Result<void>> removeCollaborator(String pieceId, String userId) =>
      _resolve().removeCollaborator(pieceId, userId);

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
    String? teacherName,
  }) => _resolve().importPiece(
    title: title,
    sourcePath: sourcePath,
    teacherName: teacherName,
  );

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
    String? studentName,
    String? studentEmail,
    String? teacherName,
  }) => _resolve().pairStudent(
    pieceId,
    studentId: studentId,
    studentName: studentName,
    studentEmail: studentEmail,
    teacherName: teacherName,
  );

  @override
  Future<Result<Piece>> registerImportedPiece({
    required String pieceId,
    required String title,
    required String teacherId,
    required String sourcePath,
    String? studentId,
    String? teacherName,
    String? studentName,
  }) => _resolve().registerImportedPiece(
    pieceId: pieceId,
    title: title,
    teacherId: teacherId,
    sourcePath: sourcePath,
    studentId: studentId,
    teacherName: teacherName,
    studentName: studentName,
  );

  @override
  Stream<List<Piece>> watchPieces() => _resolve().watchPieces();
}
