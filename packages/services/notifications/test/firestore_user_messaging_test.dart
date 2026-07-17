import 'package:core_utils/core_utils.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';

void main() {
  group('FirestoreUserMessaging', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreUserMessaging messaging;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      messaging = FirestoreUserMessaging(firestore: firestore);
    });

    test('sendToUser then inboxFor round-trips the message', () async {
      final message = UserMessage(
        id: 'm1',
        toUid: 'uid-1',
        title: 'Invite',
        body: 'Join a shared piece',
        sentAt: DateTime(2024, 1, 2),
        data: const {'type': 'invite', 'pieceId': 'p1'},
      );

      final sendResult = await messaging.sendToUser(message);
      expect(sendResult, isA<Success<void>>());

      final inbox = await messaging.inboxFor('uid-1').first;

      expect(inbox, [message]);
    });

    test('sendToUser round-trips requiresAction', () async {
      final message = UserMessage(
        id: 'm1',
        toUid: 'uid-1',
        title: 'Invite',
        body: 'Join a shared piece',
        sentAt: DateTime(2024, 1, 2),
        requiresAction: true,
      );

      await messaging.sendToUser(message);

      final inbox = await messaging.inboxFor('uid-1').first;
      expect(inbox.single.requiresAction, isTrue);
    });

    test(
      'a document written without requiresAction reads back as false',
      () async {
        // Documents predating the field (and any sender that omits it) must
        // keep their original consumed-once-surfaced behaviour.
        await firestore
            .collection('userInbox')
            .doc('uid-1')
            .collection('messages')
            .doc('legacy')
            .set(<String, dynamic>{
              'toUid': 'uid-1',
              'title': 'Nudge',
              'body': 'Open the sheet',
              'data': <String, String>{'type': 'nudge'},
              'sentAtMillis': DateTime(2024, 1, 2).millisecondsSinceEpoch,
              'read': false,
            });

        final inbox = await messaging.inboxFor('uid-1').first;
        expect(inbox.single.requiresAction, isFalse);
      },
    );

    test(
      'a server-marked pushed document reads back pushed; absent is false',
      () async {
        // `pushed` is server-owned: `onInboxMessageCreated` merges it in
        // after a successful FCM fan-out. Clients never write it, so an
        // absent field must read back false (bridge shows the message).
        final inboxDocs = firestore
            .collection('userInbox')
            .doc('uid-1')
            .collection('messages');
        final base = <String, dynamic>{
          'toUid': 'uid-1',
          'title': 'Nudge',
          'body': 'Open the sheet',
          'data': <String, String>{'type': 'nudge'},
          'sentAtMillis': DateTime(2024, 1, 2).millisecondsSinceEpoch,
          'read': false,
        };
        await inboxDocs.doc('pushed').set(<String, dynamic>{
          ...base,
          'pushed': true,
        });
        await inboxDocs.doc('unpushed').set(base);

        final inbox = await messaging.inboxFor('uid-1').first;
        final byId = {for (final m in inbox) m.id: m};
        expect(byId['pushed']!.pushed, isTrue);
        expect(byId['unpushed']!.pushed, isFalse);
      },
    );

    test('inboxFor only ever includes messages for that uid', () async {
      await messaging.sendToUser(
        UserMessage(
          id: 'm1',
          toUid: 'uid-a',
          title: 'A',
          body: 'body',
          sentAt: DateTime(2024),
        ),
      );

      expect(await messaging.inboxFor('uid-b').first, isEmpty);
    });

    test('markRead removes the message from the live inbox stream', () async {
      final message = UserMessage(
        id: 'm1',
        toUid: 'uid-1',
        title: 'Invite',
        body: 'Join',
        sentAt: DateTime(2024),
      );
      await messaging.sendToUser(message);

      final markResult = await messaging.markRead('uid-1', 'm1');
      expect(markResult, isA<Success<void>>());

      expect(await messaging.inboxFor('uid-1').first, isEmpty);
    });

    test('register then unregister round-trips a device token', () async {
      final registerResult = await messaging.register('uid-1', 'token-a');
      expect(registerResult, isA<Success<void>>());

      final doc = await firestore.collection('deviceTokens').doc('uid-1').get();
      expect(doc.data()!['tokens'], ['token-a']);

      final unregisterResult = await messaging.unregister('uid-1', 'token-a');
      expect(unregisterResult, isA<Success<void>>());

      final after = await firestore
          .collection('deviceTokens')
          .doc('uid-1')
          .get();
      expect(after.data()!['tokens'], isEmpty);
    });
  });
}
