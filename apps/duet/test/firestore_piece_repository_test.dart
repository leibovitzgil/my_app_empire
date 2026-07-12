// Mirrors local_piece_repository_test.dart's coverage against Firestore via
// `fake_cloud_firestore`. The fake evaluates NO security rules — the rules
// matrix (participant scoping, ownership, immutable participantIds) is proven
// separately by the M2.3 emulator suite; here we exercise the repository logic.
import 'dart:io';

import 'package:core_utils/core_utils.dart';
import 'package:duet/data/firestore_piece_mappers.dart';
import 'package:duet/data/firestore_piece_repository.dart';
import 'package:duet/domain/domain.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
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

  group('FirestorePieceRepository', () {
    late FakeFirebaseFirestore firestore;
    late Directory tempDir;
    late File sourcePdf;
    late LocalStorageService storage;
    late FirestorePieceRepository repository;
    late String currentUserId;

    Future<Directory> documentsDirectory() async => tempDir;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      tempDir = await Directory.systemTemp.createTemp('firestore_pieces');
      sourcePdf = File('${tempDir.path}/source.pdf')
        ..writeAsStringSync('%PDF-1.4 fake');
      SharedPreferences.setMockInitialValues(<String, Object>{});
      storage = LocalStorageService(await SharedPreferences.getInstance());
      currentUserId = 'owner-1';
      repository = FirestorePieceRepository(
        firestore: firestore,
        currentUserId: () => currentUserId,
        pdfRenderService: _FakePdfRenderService(),
        storage: storage,
        documentsDirectory: documentsDirectory,
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    Future<Piece> importPiece({String title = 'Nocturne', String? ownerName}) =>
        repository
            .importPiece(
              title: title,
              sourcePath: sourcePdf.path,
              ownerName: ownerName,
            )
            .then((r) => r.orThrow());

    test(
      'importPiece stages the PDF, checksums it, and writes the doc',
      () async {
        final piece = await importPiece();

        expect(piece.basePdfChecksum, 'checksum-of-source.pdf');
        expect(piece.basePdfPath, isNotEmpty);
        expect(File(piece.basePdfPath).existsSync(), isTrue);
        // The doc is really in Firestore, with the owner materialized.
        final doc = await firestore.collection('pieces').doc(piece.id).get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['participantIds'], ['owner-1']);
      },
    );

    test('importPiece stores the given ownerName', () async {
      final piece = await importPiece(ownerName: 'Olivia');
      expect(piece.ownerName, 'Olivia');
    });

    test('importPiece leaves ownerName null when not given one', () async {
      final piece = await importPiece();
      expect(piece.ownerName, isNull);
    });

    test('getPiece fails for an unknown id', () async {
      final result = await repository.getPiece('nope');
      expect(result, isA<ResultFailure<Piece>>());
    });

    test('getPiece hydrates basePdfPath from the local cache', () async {
      final piece = await importPiece();
      final fetched = (await repository.getPiece(piece.id)).orThrow();
      expect(fetched.basePdfPath, piece.basePdfPath);
    });

    test('watchPieces shows only pieces the caller participates in', () async {
      final mine = await importPiece();

      // A piece owned by someone else, seeded directly.
      await firestore
          .collection('pieces')
          .doc('other')
          .set(
            pieceToFirestore(
              Piece(
                id: 'other',
                title: 'Someone else',
                basePdfChecksum: 'x',
                basePdfPath: '',
                ownerId: 'stranger',
                createdAt: DateTime.utc(2024),
                updatedAt: DateTime.utc(2024),
              ),
            ),
          );

      final visible = await repository.watchPieces().firstWhere(
        (p) => p.isNotEmpty,
      );
      expect(visible.map((p) => p.id), [mine.id]);
    });

    test('watchPieces sorts by updatedAt, most recent first', () async {
      final first = await importPiece(title: 'First');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await importPiece(title: 'Second');

      final visible = await repository.watchPieces().firstWhere(
        (p) => p.length == 2,
      );
      expect(visible.map((p) => p.id), [second.id, first.id]);
    });

    test('a collaborator sees the piece once added (participantIds)', () async {
      final piece = await importPiece();
      (await repository.addCollaborator(
        piece.id,
        userId: 'collab-1',
      )).orThrow();

      currentUserId = 'collab-1';
      final visible = await repository.watchPieces().firstWhere(
        (p) => p.isNotEmpty,
      );
      expect(visible.map((p) => p.id), [piece.id]);
    });

    test('renamePiece updates the title', () async {
      final piece = await importPiece();
      (await repository.renamePiece(piece.id, 'Renamed')).orThrow();
      expect((await repository.getPiece(piece.id)).orThrow().title, 'Renamed');
    });

    test(
      'deletePiece is owner-only (OwnershipViolation for a non-owner)',
      () async {
        final piece = await importPiece();
        currentUserId = 'not-owner';

        final result = await repository.deletePiece(piece.id);

        expect(result, isA<ResultFailure<void>>());
        expect(
          (result as ResultFailure<void>).error,
          isA<OwnershipViolation>(),
        );
        expect(
          (await firestore.collection('pieces').doc(piece.id).get()).exists,
          isTrue,
        );
      },
    );

    test('deletePiece removes the doc for the owner', () async {
      final piece = await importPiece();
      (await repository.deletePiece(piece.id)).orThrow();
      expect(
        (await firestore.collection('pieces').doc(piece.id).get()).exists,
        isFalse,
      );
    });

    test('addCollaborator is idempotent for the same userId', () async {
      final piece = await importPiece();
      (await repository.addCollaborator(
        piece.id,
        userId: 'c1',
        name: 'Ann',
      )).orThrow();
      (await repository.addCollaborator(piece.id, userId: 'c1')).orThrow();

      final updated = (await repository.getPiece(piece.id)).orThrow();
      expect(updated.collaborators, hasLength(1));
      // The name isn't clobbered with null on the second (bare) add.
      expect(updated.collaborators.single.name, 'Ann');
    });

    test('pairCollaborator stores the collaborator name and email', () async {
      final piece = await importPiece();
      (await repository.pairCollaborator(
        piece.id,
        collaboratorId: 'c1',
        collaboratorName: 'Ravi',
        collaboratorEmail: 'ravi@example.com',
      )).orThrow();

      final updated = (await repository.getPiece(piece.id)).orThrow();
      expect(updated.collaborators.single.name, 'Ravi');
      expect(updated.collaborators.single.email, 'ravi@example.com');
    });

    test(
      'pairCollaborator backfills ownerName but never clobbers it',
      () async {
        final piece = await importPiece(ownerName: 'Original');
        final paired = (await repository.pairCollaborator(
          piece.id,
          collaboratorId: 'c1',
          ownerName: 'Should Not Win',
        )).orThrow();
        expect(paired.ownerName, 'Original');

        // Backfill path: a piece imported without an owner name.
        final anon = await importPiece();
        final backfilled = (await repository.pairCollaborator(
          anon.id,
          collaboratorId: 'c2',
          ownerName: 'Backfilled',
        )).orThrow();
        expect(backfilled.ownerName, 'Backfilled');
      },
    );

    test('removeCollaborator is a no-op when not a collaborator', () async {
      final piece = await importPiece();
      final result = await repository.removeCollaborator(piece.id, 'ghost');
      expect(result, isA<Success<void>>());
    });

    test('removeCollaborator is owner-only', () async {
      final piece = await importPiece();
      (await repository.addCollaborator(piece.id, userId: 'c1')).orThrow();
      currentUserId = 'c1';

      final result = await repository.removeCollaborator(piece.id, 'c1');

      expect((result as ResultFailure<void>).error, isA<OwnershipViolation>());
    });

    test('the owner cannot leave their own piece', () async {
      final piece = await importPiece();
      final result = await repository.leavePiece(piece.id);
      expect(result, isA<ResultFailure<void>>());
    });

    test('a collaborator can leave (dropped from participantIds)', () async {
      final piece = await importPiece();
      (await repository.addCollaborator(piece.id, userId: 'c1')).orThrow();
      currentUserId = 'c1';

      (await repository.leavePiece(piece.id)).orThrow();

      final doc = await firestore.collection('pieces').doc(piece.id).get();
      expect(doc.data()!['participantIds'], ['owner-1']);
    });

    test('registerImportedPiece preserves the given id and owner', () async {
      final piece = (await repository.registerImportedPiece(
        pieceId: 'shared-1',
        title: 'From a friend',
        ownerId: 'friend',
        sourcePath: sourcePdf.path,
        collaboratorId: 'owner-1',
        ownerName: 'Friend',
      )).orThrow();

      expect(piece.id, 'shared-1');
      expect(piece.ownerId, 'friend');
      expect(piece.collaborators.single.uid, 'owner-1');
    });

    test('registerImportedPiece fails for a duplicate id', () async {
      await repository.registerImportedPiece(
        pieceId: 'dup',
        title: 'One',
        ownerId: 'friend',
        sourcePath: sourcePdf.path,
      );
      final second = await repository.registerImportedPiece(
        pieceId: 'dup',
        title: 'Two',
        ownerId: 'friend',
        sourcePath: sourcePdf.path,
      );
      expect(second, isA<ResultFailure<Piece>>());
    });
  });
}
