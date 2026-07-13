// The plan-M3 exit: drives the whole cloud-pieces loop against the REAL
// Firebase emulator suite (Auth + Firestore + Functions + Storage) at the
// repository/service layer, proving `useFirebase: true` end-to-end —
//
//   owner imports + uploads a sheet -> invites by email (M2.4/M3.6 callables)
//   -> collaborator accepts (server-authoritative participant add, M3.8) ->
//   collaborator sees it in their gallery -> collaborator draws a stroke +
//   records an audio note -> owner sees both live -> an offline edit ->
//   reconnect -> converged -> owner deletes the piece -> the collaborator's
//   gallery empties and the piece's Storage prefix is gone (onPieceDeleted
//   cascade).
//
// Like `collaborator_flow_test.dart`, this needs `firebase emulators:start`
// (config in `firebase.json`, all four emulators — see `./dev.sh`) already
// running AND an engine, so it CANNOT run in the headless sandbox; it's opt-in
// via `melos run e2e` (or `flutter test integration_test/cloud_pieces_flow_test.dart
// -d chrome` with `./dev.sh --emulators-only`) and is deliberately excluded
// from the standard headless gate (`melos run test`, which exercises the
// in-memory fakes in `test/`). Duet is single-device: one process switches
// between the owner and collaborator identities, but every read here goes
// through the real Firestore, scoped by `participantIds`, so the two accounts
// genuinely see the cloud state, not a shared on-device blob.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/app.dart';
import 'package:duet/data/callable_account_purge.dart' show duetFunctionsRegion;
import 'package:duet/data/current_user.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:duet/injection.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:user_directory/user_directory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const ownerEmail = 'owner.pieces@duet.dev';
  const collaboratorEmail = 'collab.pieces@duet.dev';
  const password = 'correct horse battery staple';

  late Directory scratch;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('cloud_pieces_e2e');
  });
  tearDown(() async {
    if (scratch.existsSync()) await scratch.delete(recursive: true);
  });

  Future<String> makeFile(String name, String contents) async {
    final file = File('${scratch.path}/$name')..writeAsStringSync(contents);
    return file.path;
  }

  Future<void> signIn(String email) async {
    await firebase_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  testWidgets(
    'cloud pieces loop: import + upload -> invite -> accept -> annotate '
    '(offline then reconnect) -> owner sees live -> delete cascades',
    (tester) async {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'demo',
          appId: '1:0:web:demo',
          messagingSenderId: '0',
          projectId: 'demo-duet',
          storageBucket: 'demo-duet.appspot.com',
        ),
      );
      await firebase_auth.FirebaseAuth.instance.useAuthEmulator(
        '127.0.0.1',
        9099,
      );
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
      FirebaseFunctions.instanceFor(
        region: duetFunctionsRegion,
      ).useFunctionsEmulator('127.0.0.1', 5001);
      await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
      await configureDependencies(useFirebase: true);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Two fresh accounts (the emulator accepts any unseen email/password).
      await firebase_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: ownerEmail,
        password: password,
      );
      await getIt<AuthRepository>().login(ownerEmail, password);
      await tester.pumpAndSettle();
      final ownerId = getIt<CurrentUser>().call();

      await firebase_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: collaboratorEmail,
        password: password,
      );
      final collaboratorId =
          firebase_auth.FirebaseAuth.instance.currentUser!.uid;
      // Publish the collaborator's directory entry so the invite resolves.
      await getIt<UserDirectory>().upsertSelf(
        DirectoryUser(
          uid: collaboratorId,
          email: collaboratorEmail,
          displayName: 'Collab',
        ),
      );
      await signIn(ownerEmail);
      await tester.pumpAndSettle();

      // 1. Owner imports the sheet (writes the Firestore doc) and uploads its
      // base PDF to Storage.
      final pdfPath = await makeFile('base.pdf', '%PDF-1.4 e2e');
      final piece = (await getIt<PieceRepository>().importPiece(
        title: 'Nocturne',
        sourcePath: pdfPath,
        ownerName: 'Owner',
      )).orThrow();
      await getIt<PieceBinaryStore>()
          .uploadBasePdf(
            pieceId: piece.id,
            localPath: pdfPath,
            checksum: piece.basePdfChecksum,
          )
          .drain<void>();

      // 2. Owner invites the collaborator by email (sendInvite callable).
      final sent = await getIt<CollaboratorInviteService>().sendInvite(
        pieceId: piece.id,
        ownerId: ownerId,
        email: collaboratorEmail,
        ownerName: 'Owner',
      );
      expect(sent.isSuccess, isTrue);

      // 3. Collaborator signs in and accepts — the acceptInvite callable adds
      // them to `participantIds`/`collaborators` server-side (M3.8).
      await getIt<AuthRepository>().logout();
      await signIn(collaboratorEmail);
      await tester.pumpAndSettle();

      final invites = await getIt<CollaboratorInviteService>()
          .watchInvites(collaboratorId)
          .first;
      expect(invites, hasLength(1));
      (await getIt<CollaboratorInviteService>().acceptInvite(
        invites.single,
        accepterId: collaboratorId,
        accepterName: 'Collab',
        accepterEmail: collaboratorEmail,
      )).orThrow();

      // The piece now shows up in the collaborator's gallery.
      final collabGallery = await getIt<PieceRepository>()
          .watchPieces()
          .firstWhere((pieces) => pieces.any((p) => p.id == piece.id));
      expect(collabGallery.single.id, piece.id);

      // 4. Collaborator annotates: a stroke drawn OFFLINE, plus an audio note.
      await FirebaseFirestore.instance.disableNetwork();
      final stroke = InkStroke(
        id: 's1',
        authorId: collaboratorId,
        pageIndex: 0,
        colorId: 'ink',
        points: const [InkPoint(x: 0.2, y: 0.3)],
      );
      (await getIt<AnnotationRepository>().addStroke(
        piece.id,
        stroke,
      )).orThrow();
      // Reconnect — the offline stroke flushes and converges.
      await FirebaseFirestore.instance.enableNetwork();

      final audioPath = await makeFile('note.m4a', 'sound');
      final assetId = (await getIt<AudioAssetStore>().put(
        audioPath,
        pieceId: piece.id,
      )).orThrow();
      final note = AudioNote(
        id: 'n1',
        authorId: collaboratorId,
        audioAssetId: assetId,
        pageIndex: 0,
        durationMs: 1000,
        region: const Region(
          pageIndex: 0,
          left: 0.2,
          top: 0.3,
          width: 0.1,
          height: 0.1,
        ),
        createdAt: DateTime(2026, 7, 13),
      );
      (await getIt<AnnotationRepository>().addAudioNote(
        piece.id,
        note,
      )).orThrow();

      // 5. The owner sees the collaborator's stroke and pin live.
      await getIt<AuthRepository>().logout();
      await signIn(ownerEmail);
      await tester.pumpAndSettle();

      final ownerView = await getIt<AnnotationRepository>()
          .watch(piece.id)
          .firstWhere(
            (a) =>
                a.layers.any((l) => l.strokes.isNotEmpty) &&
                a.audioNotes.isNotEmpty,
          );
      expect(
        ownerView.layers.expand((l) => l.strokes).map((s) => s.id),
        contains('s1'),
      );
      expect(ownerView.audioNotes.single.id, 'n1');

      // 6. Owner deletes the piece — onPieceDeleted cascades its
      // subcollections + Storage prefix.
      (await getIt<PieceRepository>().deletePiece(piece.id)).orThrow();

      // The collaborator's gallery empties.
      await getIt<AuthRepository>().logout();
      await signIn(collaboratorEmail);
      await tester.pumpAndSettle();
      final afterDelete = await getIt<PieceRepository>()
          .watchPieces()
          .firstWhere((pieces) => pieces.every((p) => p.id != piece.id));
      expect(afterDelete.where((p) => p.id == piece.id), isEmpty);

      // The Storage prefix is gone (the cascade deleted base.pdf + audio).
      final remaining = await FirebaseStorage.instance
          .ref('pieces/${piece.id}')
          .listAll();
      expect(remaining.items, isEmpty);
      expect(remaining.prefixes, isEmpty);
    },
  );
}
