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
        final data = (await _doc(email).get()).data();
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
