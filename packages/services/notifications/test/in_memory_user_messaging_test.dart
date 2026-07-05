import 'package:core_utils/core_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';

void main() {
  group('InMemoryUserMessaging', () {
    late InMemoryUserMessaging messaging;

    setUp(() {
      messaging = InMemoryUserMessaging();
    });

    test('inboxFor emits an empty snapshot before anything is sent', () async {
      expect(await messaging.inboxFor('uid-1').first, isEmpty);
    });

    test(
      "sendToUser is seen on the recipient's inbox stream (the shared "
      'singleton trick)',
      () async {
        final events = <List<UserMessage>>[];
        final subscription = messaging.inboxFor('uid-2').listen(events.add);
        addTearDown(subscription.cancel);
        await pumpEventQueue();

        final message = UserMessage(
          id: 'm1',
          toUid: 'uid-2',
          title: 'Hi',
          body: 'Join my piece',
          sentAt: DateTime(2024),
          data: const {'type': 'invite'},
        );
        final result = await messaging.sendToUser(message);

        expect(result, isA<Success<void>>());
        await pumpEventQueue();
        expect(events.last, [message]);
      },
    );

    test(
      'sendToUser to a different uid is not seen by another inbox',
      () async {
        await messaging.sendToUser(
          UserMessage(
            id: 'm1',
            toUid: 'uid-a',
            title: 'Hi',
            body: 'Body',
            sentAt: DateTime(2024),
          ),
        );

        expect(await messaging.inboxFor('uid-b').first, isEmpty);
      },
    );

    test('markRead removes the message from the live inbox snapshot', () async {
      final message = UserMessage(
        id: 'm1',
        toUid: 'uid-1',
        title: 'Hi',
        body: 'Body',
        sentAt: DateTime(2024),
      );
      await messaging.sendToUser(message);

      final events = <List<UserMessage>>[];
      final subscription = messaging.inboxFor('uid-1').listen(events.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      final markResult = await messaging.markRead('uid-1', 'm1');

      expect(markResult, isA<Success<void>>());
      await pumpEventQueue();
      expect(events.last, isEmpty);
    });

    test('markRead is a no-op for an unknown id', () async {
      final result = await messaging.markRead('uid-1', 'nope');
      expect(result, isA<Success<void>>());
    });

    test('register/unregister track tokens per uid', () async {
      await messaging.register('uid-1', 'token-a');
      await messaging.register('uid-1', 'token-b');

      expect(messaging.tokensFor('uid-1'), {'token-a', 'token-b'});

      await messaging.unregister('uid-1', 'token-a');

      expect(messaging.tokensFor('uid-1'), {'token-b'});
    });
  });
}
