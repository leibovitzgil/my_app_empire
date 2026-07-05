// Drives the collaborator email-invite -> accept funnel against the REAL
// Firebase Auth + Firestore emulator (see `lib/main_emulator.dart`), proving
// the `useFirebase: true` wiring end-to-end — the headless gate only ever
// exercises the in-memory fakes (`test/injection_test.dart`,
// `test/duet_flow_test.dart`), never this real backend.
//
// `flutter test integration_test/collaborator_flow_test.dart` needs BOTH a
// device/engine (see the `flutter-e2e` skill) AND
// `firebase emulators:start` (config in `firebase.json`) already running,
// so this can't run in this sandbox; it's opt-in via `melos run e2e` on a
// machine with the Firebase CLI + a device available and is deliberately
// excluded from the standard headless gate.
//
// Duet is a single-device app: `PieceRepository` persists to on-device
// storage shared by every signed-in identity on that device (the same
// convention `test/duet_flow_test.dart`/`duet_flow_harness.dart` use, where
// "teacher" and "student" are simulated on one process) — so a piece the
// teacher identity imports is still there once this test switches to the
// student identity, exactly as it would be for, say, a shared family
// device. What's genuinely real here is the Auth sign-in and the
// Firestore-backed directory lookup/invite-send/invite-read/accept-record
// round trip, not cross-device piece sync (that's `services/review_sync`'s
// job, unrelated to this feature).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/app.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/injection.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pieces/pieces.dart';
import 'package:user_directory/user_directory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const teacherEmail = 'teacher.e2e@duet.dev';
  const studentEmail = 'student.e2e@duet.dev';
  const password = 'correct horse battery staple';

  testWidgets(
    'email invite -> real Firestore delivery -> accept records the '
    'collaborator (AC-1, AC-2, AC-12, AC-13) against the live emulator',
    (tester) async {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'demo',
          appId: '1:0:web:demo',
          messagingSenderId: '0',
          projectId: 'demo-duet',
        ),
      );
      await firebase_auth.FirebaseAuth.instance.useAuthEmulator(
        '127.0.0.1',
        9099,
      );
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
      await configureDependencies(useFirebase: true);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // 1. The teacher signs in (the emulator accepts any never-before-seen
      // email/password pair as a fresh account) and publishes their own
      // directory entry (the auth-change `upsertSelf` listener wired in
      // `injection.dart`).
      await firebase_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: teacherEmail,
        password: password,
      );
      await getIt<AuthRepository>().login(teacherEmail, password);
      await tester.pumpAndSettle();
      final teacherId = getIt<CurrentUser>().call();

      // Publish the student's directory entry directly (standing in for
      // the student's own device having signed in at least once) so the
      // teacher's invite can resolve it.
      await firebase_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: studentEmail,
        password: password,
      );
      final studentId = firebase_auth.FirebaseAuth.instance.currentUser!.uid;
      await getIt<UserDirectory>().upsertSelf(
        DirectoryUser(
          uid: studentId,
          email: studentEmail,
          displayName: 'Student E2E',
        ),
      );
      // Sign back in as the teacher for the rest of this "device session".
      await firebase_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: teacherEmail,
        password: password,
      );
      await tester.pumpAndSettle();

      // 2. The teacher imports a piece and sends a real email invite —
      // written to the live Firestore emulator, not an in-memory fake.
      final piece = (await getIt<PieceRepository>().importPiece(
        title: 'Clair de Lune',
        sourcePath: 'clair_de_lune.pdf',
        teacherName: 'Teacher E2E',
      )).orThrow();

      final sendResult = await getIt<CollaboratorInviteService>().sendInvite(
        pieceId: piece.id,
        ownerId: teacherId,
        email: studentEmail,
        ownerName: 'Teacher E2E',
      );
      expect(sendResult.isSuccess, isTrue);
      expect((sendResult as Success<LookupOutcome>).value, isA<Resolved>());

      // 3. The invite is really sitting in the student's Firestore inbox.
      final inboxSnapshot = await FirebaseFirestore.instance
          .collection('userInbox')
          .doc(studentId)
          .collection('messages')
          .where('read', isEqualTo: false)
          .get();
      expect(inboxSnapshot.docs, isNotEmpty);

      // 4. Switch this device's signed-in identity to the student and
      // accept — the on-device `PieceRepository` already has the piece
      // (see this file's top-of-file note), so `addCollaborator` succeeds.
      await getIt<AuthRepository>().logout();
      await firebase_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: studentEmail,
        password: password,
      );
      await tester.pumpAndSettle();

      final invites = await getIt<CollaboratorInviteService>()
          .watchInvites(studentId)
          .first;
      expect(invites, hasLength(1));
      expect(invites.single.pieceId, piece.id);

      final acceptResult = await getIt<CollaboratorInviteService>()
          .acceptInvite(
            invites.single,
            accepterId: studentId,
            accepterName: 'Student E2E',
            accepterEmail: studentEmail,
          );
      expect(acceptResult.isSuccess, isTrue);

      final updated = (await getIt<PieceRepository>().getPiece(
        piece.id,
      )).orThrow();
      expect(updated.isCollaborator(studentId), isTrue);
      final collaborator = updated.collaborators.firstWhere(
        (c) => c.uid == studentId,
      );
      expect(collaborator.email, studentEmail);
    },
  );
}
