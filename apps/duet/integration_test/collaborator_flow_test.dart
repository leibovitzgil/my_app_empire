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
// the owner and a collaborator are simulated on one process) — so a sheet the
// owner identity imports is still there once this test switches to the
// collaborator identity, exactly as it would be for, say, a shared family
// device. What's genuinely real here is the Auth sign-in and the
// Firestore-backed directory lookup/invite-send/invite-read/accept-record
// round trip, not cross-device sheet sync (that's `services/review_sync`'s
// job, unrelated to this feature).
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
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:user_directory/user_directory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const ownerEmail = 'owner.e2e@duet.dev';
  const collaboratorEmail = 'collaborator.e2e@duet.dev';
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
      // The invite send/accept now go through Cloud Functions (M2.4), so the
      // Functions emulator must be up too (dev.sh boots it).
      FirebaseFunctions.instanceFor(
        region: duetFunctionsRegion,
      ).useFunctionsEmulator('127.0.0.1', 5001);
      await configureDependencies(useFirebase: true);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // 1. The owner signs in (the emulator accepts any never-before-seen
      // email/password pair as a fresh account) and publishes their own
      // directory entry (the auth-change `upsertSelf` listener wired in
      // `injection.dart`).
      await firebase_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: ownerEmail,
        password: password,
      );
      await getIt<AuthRepository>().login(ownerEmail, password);
      await tester.pumpAndSettle();
      final ownerId = getIt<CurrentUser>().call();

      // Publish the collaborator's directory entry directly (standing in for
      // the collaborator's own device having signed in at least once) so the
      // owner's invite can resolve it.
      await firebase_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: collaboratorEmail,
        password: password,
      );
      final collaboratorId =
          firebase_auth.FirebaseAuth.instance.currentUser!.uid;
      await getIt<UserDirectory>().upsertSelf(
        DirectoryUser(
          uid: collaboratorId,
          email: collaboratorEmail,
          displayName: 'Collaborator E2E',
        ),
      );
      // Sign back in as the owner for the rest of this "device session".
      await firebase_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: ownerEmail,
        password: password,
      );
      await tester.pumpAndSettle();

      // 2. The owner imports a sheet and sends an email invite — the
      // `sendInvite` Cloud Function (M2.4) resolves the invitee and writes
      // their inbox with the Admin SDK; the client can no longer write it
      // directly (rules `userInbox create: if false`). The callable returns
      // the resolved recipient.
      final piece = (await getIt<PieceRepository>().importPiece(
        title: 'Clair de Lune',
        sourcePath: 'clair_de_lune.pdf',
        ownerName: 'Owner E2E',
      )).orThrow();

      final sendResult = await getIt<CollaboratorInviteService>().sendInvite(
        pieceId: piece.id,
        ownerId: ownerId,
        email: collaboratorEmail,
        ownerName: 'Owner E2E',
      );
      expect(sendResult.isSuccess, isTrue);
      final resolved = (sendResult as Success<LookupOutcome>).value;
      expect(resolved, isA<Resolved>());
      expect((resolved as Resolved).recipient.uid, collaboratorId);

      // 3. Switch this device's signed-in identity to the collaborator. The
      // invite is really in their Firestore inbox — proven by reading it as
      // themselves via the service (a recipient read the rules still allow),
      // not the owner (whom the recipient-only rule would deny). Acceptance is
      // server-authoritative now (M3.8): the `acceptInvite` callable adds the
      // caller to `pieces/{id}.participantIds`/`collaborators` (the rules make
      // those immutable to clients), so `getPiece` below sees the membership.
      await getIt<AuthRepository>().logout();
      await firebase_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: collaboratorEmail,
        password: password,
      );
      await tester.pumpAndSettle();

      final invites = await getIt<CollaboratorInviteService>()
          .watchInvites(collaboratorId)
          .first;
      expect(invites, hasLength(1));
      expect(invites.single.pieceId, piece.id);

      final acceptResult = await getIt<CollaboratorInviteService>()
          .acceptInvite(
            invites.single,
            accepterId: collaboratorId,
            accepterName: 'Collaborator E2E',
            accepterEmail: collaboratorEmail,
          );
      expect(acceptResult.isSuccess, isTrue);

      final updated = (await getIt<PieceRepository>().getPiece(
        piece.id,
      )).orThrow();
      expect(updated.isCollaborator(collaboratorId), isTrue);
      final collaborator = updated.collaborators.firstWhere(
        (c) => c.uid == collaboratorId,
      );
      expect(collaborator.email, collaboratorEmail);
    },
  );
}
