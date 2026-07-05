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
