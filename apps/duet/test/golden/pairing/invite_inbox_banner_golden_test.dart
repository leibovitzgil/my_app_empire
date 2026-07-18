@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';
import 'package:notifications/notifications.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes.

class MockCollaboratorInviteService extends Mock
    implements CollaboratorInviteService {}

class MockUserMessageGateway extends Mock implements UserMessageGateway {}

class MockMonetizationService extends Mock implements MonetizationService {}

void main() {
  group('InviteInboxBanner goldens', () {
    const invites = [
      InviteMessage(
        messageId: 'm1',
        pieceId: 'p1',
        ownerId: 'maya-uid',
        ownerName: 'Maya K.',
      ),
      InviteMessage(
        messageId: 'm2',
        pieceId: 'p2',
        ownerId: 'tomer-uid',
        ownerName: 'Tomer R.',
      ),
    ];

    Future<void> pumpBanner(
      WidgetTester tester, {
      required Brightness brightness,
    }) async {
      tester.view.physicalSize = const Size(900, 220);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final inviteService = MockCollaboratorInviteService();
      when(
        () => inviteService.watchInvites('me'),
      ).thenAnswer((_) => Stream.value(invites));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.testTheme(brightness: brightness),
          home: Scaffold(
            body: Column(
              children: [
                InviteInboxBanner(
                  collaboratorInviteService: inviteService,
                  messageGateway: MockUserMessageGateway(),
                  monetizationService: MockMonetizationService(),
                  currentUserId: 'me',
                  onAccepted: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      // Settle `AppTextButton`'s bounded fadeIn so the labels render at
      // full opacity and no flutter_animate timer is left pending.
      await tester.pumpAndSettle();
    }

    testWidgets('two pending invites — light', (tester) async {
      await pumpBanner(tester, brightness: Brightness.light);
      await expectLater(
        find.byType(InviteInboxBanner),
        matchesGoldenFile('goldens/invite_inbox_banner_light.png'),
      );
    });

    testWidgets('two pending invites — dark', (tester) async {
      await pumpBanner(tester, brightness: Brightness.dark);
      await expectLater(
        find.byType(InviteInboxBanner),
        matchesGoldenFile('goldens/invite_inbox_banner_dark.png'),
      );
    });
  });
}
