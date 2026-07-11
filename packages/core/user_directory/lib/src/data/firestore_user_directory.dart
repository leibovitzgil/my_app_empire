import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_utils/core_utils.dart';
import 'package:user_directory/src/domain/directory_user.dart';
import 'package:user_directory/src/domain/user_directory.dart';

/// A [UserDirectory] backed by Cloud Firestore.
///
/// Schema: a top-level `usersByEmail` collection with one document per
/// discoverable identity, keyed by a lower-cased/trimmed email, at
/// `usersByEmail/{emailKey} -> {uid, email, displayName, discoverable}`.
/// Reads are exact-key GETs only (never a list/query) — see
/// `apps/duet/firestore.rules` for the corresponding security rule, which
/// gates a GET on the document's own `discoverable` field.
class FirestoreUserDirectory implements UserDirectory {
  /// Creates a [FirestoreUserDirectory] persisting via [firestore].
  FirestoreUserDirectory({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  static String _key(String email) => email.trim().toLowerCase();

  DocumentReference<Map<String, dynamic>> _doc(String email) =>
      _firestore.collection('usersByEmail').doc(_key(email));

  @override
  Future<Result<DirectoryUser?>> lookupByEmail(String email) =>
      Result.guard(() async {
        final Map<String, dynamic>? data;
        try {
          data = (await _doc(email).get()).data();
        } on FirebaseException catch (e) {
          // The security rules deny a stranger's GET of a *non-discoverable*
          // entry (see `apps/duet/firestore.rules`) — so a denial reaches
          // the client, not empty data. By design that must be
          // indistinguishable from "no account exists" (the rules' own
          // words), and the invite-by-email UX treats a resolved-null as
          // "no account found". Mapping the denial to null keeps hidden and
          // absent identical to the caller — matching `InMemoryUserDirectory`
          // — instead of leaking a hidden account as a lookup *failure*.
          // (Found by the M1.10 auth-lifecycle emulator E2E; `fake_cloud_
          // firestore` evaluates no rules, so only the emulator surfaces it.)
          if (e.code == 'permission-denied') return null;
          rethrow;
        }
        if (data == null) return null;
        final discoverable = data['discoverable'] as bool? ?? false;
        if (!discoverable) return null;
        return DirectoryUser(
          uid: data['uid'] as String,
          email: data['email'] as String,
          displayName: data['displayName'] as String?,
          discoverable: discoverable,
        );
      });

  @override
  Future<Result<void>> upsertSelf(DirectoryUser user) => Result.guard(() async {
    await _doc(user.email).set(<String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'discoverable': user.discoverable,
    });
  });
}
