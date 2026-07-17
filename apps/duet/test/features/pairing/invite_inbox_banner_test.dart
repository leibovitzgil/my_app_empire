// Widget tests for the pending-invites banner (M5.6): every visual state
// (hidden / pending rows), plus the accept (success, at-cap, failure) and
// dismiss behaviors, over a mocked `CollaboratorInviteService` +
// `UserMessageGateway` — mirroring `invite_sheet_test.dart`'s approach of
// mocking the service seam, never the cubit.
import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:feature_paywall/feature_paywall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';
import 'package:notifications/notifications.dart';

class MockCollaboratorInviteService extends Mock
    implements CollaboratorInviteService {}

class MockUserMessageGateway extends Mock implements UserMessageGateway {}

class MockMonetizationService extends Mock implements MonetizationService {}

void main() {
  const currentUserId = 'me';
  const invite = InviteMessage(
    messageId: 'm1',
    pieceId: 'p1',
    ownerId: 'maya-uid',
    ownerName: 'Maya',
  );

  late MockCollaboratorInviteService inviteService;
  late MockUserMessageGateway messageGateway;
  late MockMonetizationService monetization;
  late StreamController<List<InviteMessage>> invitesController;

  setUpAll(() {
    registerFallbackValue(invite);
  });

  setUp(() {
    inviteService = MockCollaboratorInviteService();
    messageGateway = MockUserMessageGateway();
    monetization = MockMonetizationService();
    // Synchronous on purpose: async stream delivery proved flaky inside this
    // sandbox's fake-async test zone (mirrors `duet_flow_harness.dart`'s
    // notes) — a sync broadcast controller hands the snapshot to the cubit
    // during `add`, so one pump deterministically rebuilds the banner.
    invitesController = StreamController<List<InviteMessage>>.broadcast(
      sync: true,
    );
    when(
      () => inviteService.watchInvites(currentUserId),
    ).thenAnswer((_) => invitesController.stream);
    // The at-cap paywall sheet's own `PaywallBloc` loads offerings on start.
    when(() => monetization.getOfferings()).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await invitesController.close();
  });

  /// Emits [value] on the watched-invites stream (delivered synchronously —
  /// see the controller above), rebuilds the banner, and elapses enough fake
  /// time for the bounded row animations to complete.
  Future<void> showInvites(
    WidgetTester tester,
    List<InviteMessage> value,
  ) async {
    invitesController.add(value);
    await tester.pump();
    // Drain core_ui's bounded label animations (`AppTextButton`'s fadeIn
    // schedules a flutter_animate delay timer) so no timer is left pending
    // when the test tears the tree down.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpBanner(
    WidgetTester tester, {
    void Function(String pieceId)? onAccepted,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Column(
            children: [
              InviteInboxBanner(
                collaboratorInviteService: inviteService,
                messageGateway: messageGateway,
                monetizationService: monetization,
                currentUserId: currentUserId,
                currentUserName: 'Me',
                currentUserEmail: 'me@duet.dev',
                onAccepted: onAccepted ?? (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders nothing while there are no pending invites', (
    tester,
  ) async {
    await pumpBanner(tester);
    await showInvites(tester, const []);

    expect(find.text('Accept'), findsNothing);
    expect(find.byTooltip('Dismiss invite'), findsNothing);
  });

  testWidgets('a pending invite shows the inviter and the two actions', (
    tester,
  ) async {
    await pumpBanner(tester);
    await showInvites(tester, const [invite]);

    expect(
      find.text('Maya invited you to collaborate on a sheet.'),
      findsOneWidget,
    );
    expect(find.text('Accept'), findsOneWidget);
    expect(find.byTooltip('Dismiss invite'), findsOneWidget);
  });

  testWidgets(
    "an invite with no sender name (or the callable's empty string) "
    'falls back to "Someone"',
    (tester) async {
      await pumpBanner(tester);
      await showInvites(tester, const [
        InviteMessage(
          messageId: 'm2',
          pieceId: 'p2',
          ownerId: 'anon-uid',
          ownerName: '',
        ),
      ]);

      expect(
        find.text('Someone invited you to collaborate on a sheet.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    "Accept goes through acceptInvite with the accepter's identity, "
    'fires onAccepted with the piece id, and the row leaves with the '
    'stream update',
    (tester) async {
      when(
        () => inviteService.acceptInvite(
          invite,
          accepterId: currentUserId,
          accepterName: 'Me',
          accepterEmail: 'me@duet.dev',
        ),
      ).thenAnswer((_) async => const Success(null));

      String? acceptedPieceId;
      await pumpBanner(tester, onAccepted: (id) => acceptedPieceId = id);
      await showInvites(tester, const [invite]);

      await tester.tap(find.text('Accept'));
      await tester.pump();
      await tester.pumpAndSettle();

      verify(
        () => inviteService.acceptInvite(
          invite,
          accepterId: currentUserId,
          accepterName: 'Me',
          accepterEmail: 'me@duet.dev',
        ),
      ).called(1);
      expect(acceptedPieceId, 'p1');
      expect(find.textContaining("You're in"), findsOneWidget);

      // Acceptance consumed the message, so the next snapshot drops it.
      await showInvites(tester, const []);
      expect(find.text('Accept'), findsNothing);
    },
  );

  testWidgets(
    'Dismiss marks the message read — only that: the sender-side accept '
    'path is never touched',
    (tester) async {
      when(
        () => messageGateway.markRead(currentUserId, 'm1'),
      ).thenAnswer((_) async => const Success(null));

      await pumpBanner(tester);
      await showInvites(tester, const [invite]);

      await tester.tap(find.byTooltip('Dismiss invite'));
      await tester.pump();
      await tester.pumpAndSettle();

      verify(() => messageGateway.markRead(currentUserId, 'm1')).called(1);
      verifyNever(
        () => inviteService.acceptInvite(
          any(),
          accepterId: any(named: 'accepterId'),
          accepterName: any(named: 'accepterName'),
          accepterEmail: any(named: 'accepterEmail'),
        ),
      );

      await showInvites(tester, const []);
      expect(find.byTooltip('Dismiss invite'), findsNothing);
    },
  );

  testWidgets(
    'an accept refused by the cap re-check defers to the paywall gate '
    "(the invite sheet's pattern: PaywallScreen in a bottom sheet)",
    (tester) async {
      when(
        () => inviteService.acceptInvite(
          invite,
          accepterId: currentUserId,
          accepterName: 'Me',
          accepterEmail: 'me@duet.dev',
        ),
      ).thenAnswer(
        (_) async => const ResultFailure<void>(AtCapInviteException()),
      );

      await pumpBanner(tester);
      await showInvites(tester, const [invite]);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(find.byType(PaywallScreen), findsOneWidget);
      // The invite is NOT consumed: closing the paywall leaves it pending.
      expect(find.text('Accept'), findsOneWidget);
    },
  );

  testWidgets('any other accept failure surfaces as an error snackbar', (
    tester,
  ) async {
    when(
      () => inviteService.acceptInvite(
        invite,
        accepterId: currentUserId,
        accepterName: 'Me',
        accepterEmail: 'me@duet.dev',
      ),
    ).thenAnswer(
      (_) async => ResultFailure<void>(StateError('backend unavailable')),
    );

    await pumpBanner(tester);
    await showInvites(tester, const [invite]);

    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('backend unavailable'), findsOneWidget);
    // Still pending — the user can retry.
    expect(find.text('Accept'), findsOneWidget);
  });
}
