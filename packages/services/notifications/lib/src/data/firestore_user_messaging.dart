import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_utils/core_utils.dart';
import 'package:notifications/src/domain/device_token_registry.dart';
import 'package:notifications/src/domain/user_message.dart';
import 'package:notifications/src/domain/user_message_gateway.dart';

/// A [DeviceTokenRegistry] + [UserMessageGateway] backed by Cloud Firestore.
///
/// Schema: `deviceTokens/{uid} -> {tokens: [String, ...]}` (read by Duet's
/// `onInboxMessageCreated` Cloud Function, M5.3, which fans an inbox write
/// out over FCM and `arrayRemove`s tokens FCM reports unregistered) and
/// `userInbox/{uid}/messages/{id} ->
/// {toUid, title, body, data, sentAtMillis, read, requiresAction, pushed}`.
///
/// Send seam: [sendToUser] only ever WRITES the Firestore inbox doc — that
/// write IS the send. Deployed, the `onInboxMessageCreated` trigger picks it
/// up and multicasts a real push to the recipient's registered devices,
/// marking the doc `pushed: true` on success (server-owned; this class only
/// reads it back). The recipient's live [inboxFor] listener additionally
/// surfaces messages via a foreground local-notification bridge wired at
/// the app layer (see `InboxNotificationBridge` in
/// `apps/duet/lib/injection.dart`), which skips `pushed` messages so a
/// pushed message isn't shown twice. On the emulator there is no FCM sender
/// (and no functions running headless), so the bridge is the only delivery
/// there — same [UserMessageGateway] contract either way, no client change.
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
    // Server-owned (set by `onInboxMessageCreated` after a successful FCM
    // fan-out); absent until — and unless — a push actually delivered.
    pushed: data['pushed'] as bool? ?? false,
  );
}
