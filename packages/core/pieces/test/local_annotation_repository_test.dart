import 'package:core_utils/core_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:pieces/pieces.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fixed-answer [PieceRepository] fake for role resolution, since these
/// tests exercise `LocalAnnotationRepository` in isolation.
class _FakePieceRepository implements PieceRepository {
  _FakePieceRepository(this.piece);

  final Piece piece;

  @override
  Future<Result<Piece>> getPiece(String pieceId) async => Success(piece);

  @override
  Future<Result<void>> deletePiece(String pieceId) =>
      throw UnimplementedError();

  @override
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> leavePiece(String pieceId) => throw UnimplementedError();

  @override
  Future<Result<void>> renamePiece(String pieceId, String title) =>
      throw UnimplementedError();

  @override
  Future<Result<Piece>> pairStudent(
    String pieceId, {
    required String studentId,
  }) => throw UnimplementedError();

  @override
  Future<Result<Piece>> registerImportedPiece({
    required String pieceId,
    required String title,
    required String teacherId,
    required String sourcePath,
    String? studentId,
  }) => throw UnimplementedError();

  @override
  Stream<List<Piece>> watchPieces() => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final piece = Piece(
    id: 'piece-1',
    title: 'Clair de Lune',
    basePdfChecksum: 'abc',
    basePdfPath: '/pieces/piece-1.pdf',
    teacherId: 'teacher-1',
    studentId: 'student-1',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  group('LocalAnnotationRepository', () {
    late LocalStorageService storage;
    late String currentUserId;
    late LocalAnnotationRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      currentUserId = 'teacher-1';
      repository = LocalAnnotationRepository(
        storage: storage,
        currentUserId: () => currentUserId,
        pieceRepository: _FakePieceRepository(piece),
      );
    });

    InkStroke stroke({String id = 's1', String authorId = 'teacher-1'}) =>
        InkStroke(
          id: id,
          authorId: authorId,
          pageIndex: 0,
          colorId: 'red',
          points: const [InkPoint(x: 0.1, y: 0.2)],
        );

    AudioNote note({String id = 'n1', String authorId = 'teacher-1'}) =>
        AudioNote(
          id: id,
          authorId: authorId,
          audioAssetId: 'asset-1',
          pageIndex: 0,
          durationMs: 5000,
          region: const Region(
            pageIndex: 0,
            left: 0,
            top: 0,
            width: 0.2,
            height: 0.1,
          ),
          createdAt: DateTime(2024),
        );

    test('addStroke resolves the author role from the piece', () async {
      final result = await repository.addStroke(piece.id, stroke());
      expect(result, isA<Success<void>>());

      final annotations = await repository.watch(piece.id).first;
      expect(annotations.layers.single.role, PieceRole.teacher);
      expect(annotations.layers.single.strokes.single.id, 's1');
    });

    test(
      'addStroke rejects a stroke authored by someone other than the '
      'caller',
      () async {
        final result = await repository.addStroke(
          piece.id,
          stroke(authorId: 'student-1'),
        );

        expect(result, isA<ResultFailure<void>>());
        expect(
          (result as ResultFailure<void>).error,
          isA<OwnershipViolation>(),
        );
      },
    );

    test("eraseStroke rejects erasing another author's stroke", () async {
      currentUserId = 'teacher-1';
      await repository.addStroke(piece.id, stroke());

      currentUserId = 'student-1';
      final result = await repository.eraseStroke(piece.id, 's1');

      expect(result, isA<ResultFailure<void>>());
      expect((result as ResultFailure<void>).error, isA<OwnershipViolation>());

      final annotations = await repository.watch(piece.id).first;
      expect(annotations.layers.single.strokes, isNotEmpty);
    });

    test("eraseStroke succeeds for the stroke's own author", () async {
      await repository.addStroke(piece.id, stroke());

      final result = await repository.eraseStroke(piece.id, 's1');

      expect(result, isA<Success<void>>());
      final annotations = await repository.watch(piece.id).first;
      expect(annotations.layers.single.strokes, isEmpty);
    });

    test('addAudioNote rejects a note authored by someone else', () async {
      final result = await repository.addAudioNote(
        piece.id,
        note(authorId: 'student-1'),
      );

      expect(result, isA<ResultFailure<void>>());
      expect((result as ResultFailure<void>).error, isA<OwnershipViolation>());
    });

    test("deleteAudioNote rejects deleting another author's note", () async {
      await repository.addAudioNote(piece.id, note());

      currentUserId = 'student-1';
      final result = await repository.deleteAudioNote(piece.id, 'n1');

      expect(result, isA<ResultFailure<void>>());
      expect((result as ResultFailure<void>).error, isA<OwnershipViolation>());
    });

    test('watch emits the current state immediately, then updates', () async {
      final emissions = <int>[];
      final subscription = repository
          .watch(piece.id)
          .listen((a) => emissions.add(a.layers.length));
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(emissions, [0]);

      await repository.addStroke(piece.id, stroke());
      await pumpEventQueue();

      expect(emissions, [0, 1]);
    });

    test('mutations persist: a fresh repository resolves them', () async {
      await repository.addStroke(piece.id, stroke());
      await repository.addAudioNote(piece.id, note());

      final fresh = LocalAnnotationRepository(
        storage: storage,
        currentUserId: () => currentUserId,
        pieceRepository: _FakePieceRepository(piece),
      );

      final annotations = await fresh.watch(piece.id).first;
      expect(annotations.layers.single.strokes.single.id, 's1');
      expect(annotations.audioNotes.single.id, 'n1');
    });

    test('clearPiece wipes every stroke and audio note', () async {
      await repository.addStroke(piece.id, stroke());
      await repository.addAudioNote(piece.id, note());

      final result = await repository.clearPiece(piece.id);
      expect(result, isA<Success<void>>());

      final annotations = await repository.watch(piece.id).first;
      expect(annotations.layers, isEmpty);
      expect(annotations.audioNotes, isEmpty);
    });

    test(
      "replaceAuthorSlice wholesale-replaces an author's layer and notes "
      'without the ownership guard blocking it',
      () async {
        await repository.addStroke(piece.id, stroke(id: 'old'));
        await repository.addAudioNote(piece.id, note(id: 'old-note'));

        currentUserId = 'someone-applying-a-sync-import';
        final result = await repository.replaceAuthorSlice(
          piece.id,
          'teacher-1',
          role: PieceRole.teacher,
          strokes: [stroke(id: 'new')],
          audioNotes: [note(id: 'new-note')],
        );

        expect(result, isA<Success<void>>());
        final annotations = await repository.watch(piece.id).first;
        expect(annotations.layers.single.strokes.single.id, 'new');
        expect(annotations.audioNotes.single.id, 'new-note');
      },
    );

    test(
      "replaceAuthorSlice only touches the given author's content",
      () async {
        await repository.addStroke(piece.id, stroke(id: 'teacher-stroke'));
        currentUserId = 'student-1';
        await repository.addStroke(
          piece.id,
          stroke(id: 'student-stroke', authorId: 'student-1'),
        );

        await repository.replaceAuthorSlice(
          piece.id,
          'student-1',
          role: PieceRole.student,
          strokes: [stroke(id: 'student-stroke-v2', authorId: 'student-1')],
          audioNotes: const [],
        );

        final annotations = await repository.watch(piece.id).first;
        final strokeIds = annotations.layers
            .expand((l) => l.strokes)
            .map((s) => s.id)
            .toSet();
        expect(strokeIds, {'teacher-stroke', 'student-stroke-v2'});
      },
    );
  });
}
