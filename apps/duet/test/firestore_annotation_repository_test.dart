// Mirrors local_annotation_repository_test.dart against Firestore via
// `fake_cloud_firestore`. The fake evaluates NO security rules — the rules
// matrix (per-author layer writes, participant scoping, note-delete denial) is
// proven separately by the M2.3 emulator suite; here we exercise the repository
// logic and its live-sync (combine-latest) reads.
import 'package:core_utils/core_utils.dart';
import 'package:duet/data/firestore_annotation_repository.dart';
import 'package:duet/data/firestore_piece_mappers.dart';
import 'package:duet/domain/domain.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final piece = Piece(
    id: 'piece-1',
    title: 'Clair de Lune',
    basePdfChecksum: 'abc',
    basePdfPath: '/pieces/piece-1.pdf',
    ownerId: 'owner-1',
    collaborators: const [
      Collaborator(uid: 'collaborator-1'),
      Collaborator(uid: 'collaborator-2'),
    ],
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  group('FirestoreAnnotationRepository', () {
    late FakeFirebaseFirestore firestore;
    late String currentUserId;
    late FirestoreAnnotationRepository repository;

    FirestoreAnnotationRepository repositoryFor(String Function() userId) =>
        FirestoreAnnotationRepository(
          firestore: firestore,
          currentUserId: userId,
        );

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      // Seed the piece document: the repository derives each author's role
      // from its `ownerId`, and `watch` reads it as one of its three streams.
      await firestore
          .collection('pieces')
          .doc(piece.id)
          .set(pieceToFirestore(piece));
      currentUserId = 'owner-1';
      repository = repositoryFor(() => currentUserId);
    });

    InkStroke stroke({String id = 's1', String authorId = 'owner-1'}) =>
        InkStroke(
          id: id,
          authorId: authorId,
          pageIndex: 0,
          colorId: 'red',
          points: const [InkPoint(x: 0.1, y: 0.2)],
        );

    AudioNote note({String id = 'n1', String authorId = 'owner-1'}) =>
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
      expect(annotations.layers.single.role, PieceRole.owner);
      expect(annotations.layers.single.strokes.single.id, 's1');
    });

    test(
      'addStroke resolves the collaborator role for any current '
      'collaborator, not just the first (AC-5)',
      () async {
        currentUserId = 'collaborator-2';
        final result = await repository.addStroke(
          piece.id,
          stroke(id: 's-second', authorId: 'collaborator-2'),
        );

        expect(result, isA<Success<void>>());
        final annotations = await repository.watch(piece.id).first;
        expect(annotations.layers.single.role, PieceRole.collaborator);
        expect(annotations.layers.single.ownerId, 'collaborator-2');
      },
    );

    test(
      'two collaborators each get their own separate ink layer, without '
      'overwriting each other (AC-5)',
      () async {
        currentUserId = 'collaborator-1';
        await repository.addStroke(
          piece.id,
          stroke(id: 'from-1', authorId: 'collaborator-1'),
        );
        currentUserId = 'collaborator-2';
        await repository.addStroke(
          piece.id,
          stroke(id: 'from-2', authorId: 'collaborator-2'),
        );

        final annotations = await repository
            .watch(piece.id)
            .firstWhere(
              (a) => a.layers.length == 2,
            );
        final byOwner = {
          for (final layer in annotations.layers) layer.ownerId: layer,
        };
        expect(byOwner['collaborator-1']!.strokes.single.id, 'from-1');
        expect(byOwner['collaborator-2']!.strokes.single.id, 'from-2');
      },
    );

    test(
      'addStroke rejects a stroke authored by someone other than the caller',
      () async {
        final result = await repository.addStroke(
          piece.id,
          stroke(authorId: 'collaborator-1'),
        );

        expect(result, isA<ResultFailure<void>>());
        expect(
          (result as ResultFailure<void>).error,
          isA<OwnershipViolation>(),
        );
        // Nothing was written for the rejected author.
        final layers = await firestore
            .collection('pieces')
            .doc(piece.id)
            .collection('layers')
            .get();
        expect(layers.docs, isEmpty);
      },
    );

    test("eraseStroke rejects erasing another author's stroke", () async {
      currentUserId = 'owner-1';
      await repository.addStroke(piece.id, stroke());

      currentUserId = 'collaborator-1';
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

    test('eraseStroke fails for an unknown stroke', () async {
      final result = await repository.eraseStroke(piece.id, 'ghost');
      expect(result, isA<ResultFailure<void>>());
    });

    test('addAudioNote rejects a note authored by someone else', () async {
      final result = await repository.addAudioNote(
        piece.id,
        note(authorId: 'collaborator-1'),
      );

      expect(result, isA<ResultFailure<void>>());
      expect((result as ResultFailure<void>).error, isA<OwnershipViolation>());
    });

    test("deleteAudioNote rejects deleting another author's note", () async {
      await repository.addAudioNote(piece.id, note());

      currentUserId = 'collaborator-1';
      final result = await repository.deleteAudioNote(piece.id, 'n1');

      expect(result, isA<ResultFailure<void>>());
      expect((result as ResultFailure<void>).error, isA<OwnershipViolation>());
    });

    test("deleteAudioNote succeeds for the note's own author", () async {
      await repository.addAudioNote(piece.id, note());
      final result = await repository.deleteAudioNote(piece.id, 'n1');

      expect(result, isA<Success<void>>());
      final annotations = await repository.watch(piece.id).first;
      expect(annotations.audioNotes, isEmpty);
    });

    test(
      'deleteAudioNote tombstones rather than hard-deleting (M4.4): watch '
      'hides it, but the doc survives with deletedAt and the snapshot keeps it',
      () async {
        await repository.addAudioNote(piece.id, note());
        expect(
          await repository.deleteAudioNote(piece.id, 'n1'),
          isA<Success<void>>(),
        );

        // Hidden from the reader…
        expect((await repository.watch(piece.id).first).audioNotes, isEmpty);

        // …but the document survives as a tombstone (not a hard delete), so a
        // stale offline copy can't resurrect it, and the daily GC reclaims it.
        final doc = await firestore
            .collection('pieces')
            .doc(piece.id)
            .collection('notes')
            .doc('n1')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['deletedAt'], isNotNull);

        // The sync snapshot retains the tombstone for the review-sync export.
        final snapshot = await repository.snapshotWithTombstones(piece.id);
        expect(snapshot.audioNotes.single.id, 'n1');
        expect(snapshot.audioNotes.single.isTombstoned, isTrue);
      },
    );

    test('deleteAudioNote fails for an unknown note', () async {
      final result = await repository.deleteAudioNote(piece.id, 'ghost');
      expect(result, isA<ResultFailure<void>>());
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

    test(
      'mutations persist: a fresh repository resolves them from Firestore',
      () async {
        await repository.addStroke(piece.id, stroke());
        await repository.addAudioNote(piece.id, note());

        final fresh = repositoryFor(() => currentUserId);
        final annotations = await fresh.watch(piece.id).first;
        expect(annotations.layers.single.strokes.single.id, 's1');
        expect(annotations.audioNotes.single.id, 'n1');
      },
    );

    test(
      "a stroke written by one participant converges into another's watch",
      () async {
        (await repository.addStroke(
          piece.id,
          stroke(id: 'from-owner'),
        )).orThrow();

        final collaboratorRepo = repositoryFor(() => 'collaborator-1');
        final annotations = await collaboratorRepo
            .watch(piece.id)
            .firstWhere(
              (a) => a.layers.isNotEmpty,
            );
        expect(annotations.layers.single.ownerId, 'owner-1');
        expect(annotations.layers.single.role, PieceRole.owner);
        expect(annotations.layers.single.strokes.single.id, 'from-owner');
      },
    );

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
          'owner-1',
          role: PieceRole.owner,
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
        await repository.addStroke(piece.id, stroke(id: 'owner-stroke'));
        currentUserId = 'collaborator-1';
        await repository.addStroke(
          piece.id,
          stroke(id: 'collaborator-stroke', authorId: 'collaborator-1'),
        );

        await repository.replaceAuthorSlice(
          piece.id,
          'collaborator-1',
          role: PieceRole.collaborator,
          strokes: [
            stroke(id: 'collaborator-stroke-v2', authorId: 'collaborator-1'),
          ],
          audioNotes: const [],
        );

        final annotations = await repository
            .watch(piece.id)
            .firstWhere(
              (a) => a.layers.length == 2,
            );
        final strokeIds = annotations.layers
            .expand((l) => l.strokes)
            .map((s) => s.id)
            .toSet();
        expect(strokeIds, {'owner-stroke', 'collaborator-stroke-v2'});
      },
    );

    test(
      "removeAuthorSlice drops an author's layer and audio notes entirely, "
      'leaving other authors untouched (backs removeCollaborator/leavePiece, '
      'AC-7)',
      () async {
        await repository.addStroke(piece.id, stroke(id: 'owner-stroke'));
        await repository.addAudioNote(piece.id, note(id: 'owner-note'));
        currentUserId = 'collaborator-1';
        await repository.addStroke(
          piece.id,
          stroke(id: 'collaborator-stroke', authorId: 'collaborator-1'),
        );
        await repository.addAudioNote(
          piece.id,
          note(id: 'collaborator-note', authorId: 'collaborator-1'),
        );

        final result = await repository.removeAuthorSlice(
          piece.id,
          'collaborator-1',
        );

        expect(result, isA<Success<void>>());
        final annotations = await repository
            .watch(piece.id)
            .firstWhere(
              (a) => a.layers.length == 1,
            );
        expect(annotations.layers.map((l) => l.ownerId), ['owner-1']);
        expect(annotations.audioNotes.map((n) => n.id), ['owner-note']);
      },
    );
  });
}
