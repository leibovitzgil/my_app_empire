import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:duet/injection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications/notifications.dart';

class _MockNotificationsManager extends Mock implements NotificationsManager {}

/// Regression cover for the inbox -> local-notification bridge.
///
/// The bug this pins: the bridge used to `markRead` every message it
/// surfaced. `read` is what `acceptInvite` checks for replay, so an invite
/// was consumed the instant the recipient was notified — signing in burned
/// it, and every subsequent accept failed as "already used". Showing a
/// message and consuming it are different things.
void main() {
  late _MockNotificationsManager notifications;
  late InMemoryUserMessaging gateway;
  late StreamController<String?> userId;

  UserMessage invite(String id) => UserMessage(
    id: id,
    toUid: 'sam-uid',
    title: 'Jane invited you to collaborate',
    body: 'Join a shared piece on Duet.',
    sentAt: DateTime(2024),
    requiresAction: true,
    data: const {'type': 'invite', 'pieceId': 'p1'},
  );

  UserMessage nudge(String id) => UserMessage(
    id: id,
    toUid: 'sam-uid',
    title: 'Jane added notes',
    body: 'Open the sheet to see what changed.',
    sentAt: DateTime(2024),
    data: const {'type': 'nudge', 'pieceId': 'p1'},
  );

  setUp(() async {
    notifications = _MockNotificationsManager();
    when(
      () => notifications.showLocal(
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => const Success<void>(null));

    gateway = InMemoryUserMessaging();
    userId = StreamController<String?>.broadcast();

    await getIt.reset();
    getIt.registerLazySingletonAsync<NotificationsManager>(
      () async => notifications,
    );
  });

  tearDown(() async {
    await userId.close();
    await getIt.reset();
  });

  InboxNotificationBridge bridgeUnderTest() =>
      InboxNotificationBridge(userId: userId.stream, gateway: gateway);

  test(
    'an invite is notified but left unread, so it can still be accepted',
    () async {
      await gateway.sendToUser(invite('m1'));
      final bridge = bridgeUnderTest();
      addTearDown(bridge.dispose);

      userId.add('sam-uid');
      await pumpEventQueue();

      verify(
        () => notifications.showLocal(
          title: 'Jane invited you to collaborate',
          body: 'Join a shared piece on Duet.',
        ),
      ).called(1);
      // Still pending: `markRead` would have dropped it from the inbox.
      final inbox = await gateway.inboxFor('sam-uid').first;
      expect(inbox.single.id, 'm1');
    },
  );

  test('a nudge is consumed once shown', () async {
    await gateway.sendToUser(nudge('m1'));
    final bridge = bridgeUnderTest();
    addTearDown(bridge.dispose);

    userId.add('sam-uid');
    await pumpEventQueue();

    verify(
      () => notifications.showLocal(
        title: 'Jane added notes',
        body: 'Open the sheet to see what changed.',
      ),
    ).called(1);
    final inbox = await gateway.inboxFor('sam-uid').first;
    expect(inbox, isEmpty);
  });

  test('a pending invite is not re-notified on a later snapshot', () async {
    await gateway.sendToUser(invite('m1'));
    final bridge = bridgeUnderTest();
    addTearDown(bridge.dispose);

    userId.add('sam-uid');
    await pumpEventQueue();

    // A second message re-emits the whole inbox, including the still-unread
    // invite — which must not notify twice.
    await gateway.sendToUser(nudge('m2'));
    await pumpEventQueue();

    verify(
      () => notifications.showLocal(
        title: 'Jane invited you to collaborate',
        body: any(named: 'body'),
      ),
    ).called(1);
  });
}
