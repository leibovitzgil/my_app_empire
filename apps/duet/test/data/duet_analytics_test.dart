import 'package:duet/data/duet_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recording_app_logger.dart';

void main() {
  late RecordingAppLogger logger;
  late DuetAnalytics analytics;

  setUp(() {
    logger = RecordingAppLogger();
    analytics = DuetAnalytics(logger);
  });

  group('DuetAnalytics catalogue', () {
    test('sheetImported logs sheet_imported with the piece id', () async {
      await analytics.sheetImported(pieceId: 'p1');

      expect(logger.events.single.name, 'sheet_imported');
      expect(logger.events.single.parameters, {'piece_id': 'p1'});
    });

    test('inviteSent logs invite_sent with the method', () async {
      await analytics.inviteSent(method: DuetInviteMethod.email);
      await analytics.inviteSent(method: DuetInviteMethod.link);

      expect(logger.events, hasLength(2));
      expect(logger.events[0].name, 'invite_sent');
      expect(logger.events[0].parameters, {'method': 'email'});
      expect(logger.events[1].parameters, {'method': 'link'});
    });

    test('inviteAccepted logs invite_accepted with the method', () async {
      await analytics.inviteAccepted(method: DuetInviteMethod.link);

      expect(logger.events.single.name, 'invite_accepted');
      expect(logger.events.single.parameters, {'method': 'link'});
    });

    test('noteRecorded logs note_recorded with the duration', () async {
      await analytics.noteRecorded(durationMs: 4200);

      expect(logger.events.single.name, 'note_recorded');
      expect(logger.events.single.parameters, {'duration_ms': 4200});
    });

    test('practiceOpened logs practice_opened', () async {
      await analytics.practiceOpened();

      expect(logger.events.single.name, 'practice_opened');
      expect(logger.events.single.parameters, isNull);
    });

    test('paywallShown logs paywall_shown', () async {
      await analytics.paywallShown();

      expect(logger.events.single.name, 'paywall_shown');
    });

    test('purchaseCompleted logs purchase_completed', () async {
      await analytics.purchaseCompleted();

      expect(logger.events.single.name, 'purchase_completed');
    });

    test('signUp logs sign_up', () async {
      await analytics.signUp();

      expect(logger.events.single.name, 'sign_up');
    });

    test('screenViewed logs screen_view with the template name', () async {
      await analytics.screenViewed(screenName: '/score/:pieceId');

      expect(logger.events.single.name, 'screen_view');
      expect(
        logger.events.single.parameters,
        {'screen_name': '/score/:pieceId'},
      );
    });

    test('no catalogue event ever carries an email-shaped param', () async {
      await analytics.sheetImported(pieceId: 'p1');
      await analytics.inviteSent(method: DuetInviteMethod.email);
      await analytics.inviteAccepted(method: DuetInviteMethod.email);
      await analytics.noteRecorded(durationMs: 1);
      await analytics.practiceOpened();
      await analytics.paywallShown();
      await analytics.purchaseCompleted();
      await analytics.signUp();
      await analytics.screenViewed(screenName: '/home');

      for (final event in logger.events) {
        for (final value in (event.parameters ?? const {}).values) {
          expect('$value', isNot(contains('@')));
        }
      }
    });
  });
}
