import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_utils/core_utils.dart';
import 'package:notifications/src/domain/device_token_registry.dart';
import 'package:notifications/src/domain/user_message.dart';
import 'package:notifications/src/domain/user_message_gateway.dart';

/// A [DeviceTokenRegistry] + [UserMessageGateway] backed by Cloud Firestore.
///
/// Schema: `deviceTokens/{uid} -> {tokens: [String, ...]}` (forward-
/// provisioning only — nothing yet reads this to send a real push; see
/// `DeviceTokenSync`'s doc) and `userInbox/{uid}/messages/{id} ->
/// {toUid, title, body, data, sentAtMillis, read}`.
///
/// v1 send seam (FIX-5): [sendToUser] only ever WRITES the Firestore inbox
/// doc — the Firebase emulator has no FCM sender and Cloud Functions don't
/// run headless in this container, so there is no background push in v1.
/// The recipient's own live [inboxFor] listener is what actually surfaces
/// it, via a foreground/warm-start local notification bridge wired at the
/// app layer (see `apps/duet/lib/injection.dart`). Production later swaps
/// this method alone for a Firestore-triggered Cloud Function that reads
/// `deviceTokens/{uid}` and sends a real push — same [UserMessageGateway]
/// contract, no client change.
class FirestoreUserMessaging
    implements DeviceTokenRegistry, UserMessageGateway {
  /// Creates a [FirestoreUserMessaging] persisting via [firestore].
  FirestoreUserMessaging({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _tokensDoc(String uid) =>
      _firestore.collection('deviceTokens').doc(uid);

  CollectionReference<Map<String, dynamic>> _inbox(String uid) =>
      _firestore.collection('userInbox').doc(uid).collection('messages');

  @override
  Future<Result<void>> register(String uid, String token) =>
      Result.guard<void>(() async {
        await _tokensDoc(uid).set(<String, dynamic>{
          'tokens': FieldValue.arrayUnion(<String>[token]),
        }, SetOptions(merge: true));
      });

  @override
  Future<Result<void>> unregister(String uid, String token) =>
      Result.guard<void>(() async {
        await _tokensDoc(uid).set(<String, dynamic>{
          'tokens': FieldValue.arrayRemove(<String>[token]),
        }, SetOptions(merge: true));
      });

  @override
  Future<Result<void>> sendToUser(UserMessage message) =>
      Result.guard<void>(() async {
        await _inbox(message.toUid).doc(message.id).set(<String, dynamic>{
          'toUid': message.toUid,
          'title': message.title,
          'body': message.body,
          'data': message.data,
          'sentAtMillis': message.sentAt.millisecondsSinceEpoch,
          'read': false,
          'requiresAction': message.requiresAction,
        });
      });

  @override
  Stream<List<UserMessage>> inboxFor(String uid) {
    return _inbox(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs) _toMessage(doc.id, doc.data()),
          ],
        );
  }

  @override
  Future<Result<void>> markRead(String uid, String id) =>
      Result.guard<void>(() async {
        await _inbox(uid).doc(id).set(<String, dynamic>{
          'read': true,
        }, SetOptions(merge: true));
      });

  UserMessage _toMessage(String id, Map<String, dynamic> data) => UserMessage(
    id: id,
    toUid: data['toUid'] as String,
    title: data['title'] as String,
    body: data['body'] as String,
    sentAt: DateTime.fromMillisecondsSinceEpoch(
      data['sentAtMillis'] as int,
    ),
    data:
        (data['data'] as Map<dynamic, dynamic>?)?.map(
          (key, value) => MapEntry(key as String, value as String),
        ) ??
        const <String, String>{},
    // Absent on documents written before the field existed; `false` keeps
    // those behaving exactly as they did (consumed once surfaced).
    requiresAction: data['requiresAction'] as bool? ?? false,
  );
}
