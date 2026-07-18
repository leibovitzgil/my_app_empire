import 'package:duet/data/duet_analytics.dart';
import 'package:duet/data/duet_route_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recording_app_logger.dart';

void main() {
  late RecordingAppLogger logger;
  late DuetRouteObserver observer;

  setUp(() {
    logger = RecordingAppLogger();
    observer = DuetRouteObserver(analytics: DuetAnalytics(logger));
  });

  Route<void> route(String? name) => MaterialPageRoute<void>(
    builder: (_) => const SizedBox(),
    settings: RouteSettings(name: name),
  );

  group('DuetRouteObserver', () {
    test('a pushed named route logs one screen_view with its name', () {
      observer.didPush(route('/score/:pieceId'), null);

      expect(logger.events.single.name, 'screen_view');
      expect(
        logger.events.single.parameters,
        {'screen_name': '/score/:pieceId'},
      );
    });

    test('a replaced named route logs one screen_view', () {
      observer.didReplace(newRoute: route('/home'), oldRoute: route('/login'));

      expect(logger.named('screen_view'), hasLength(1));
      expect(logger.events.single.parameters, {'screen_name': '/home'});
    });

    test('an unnamed (transient) route logs nothing', () {
      observer.didPush(route(null), null);

      expect(logger.events, isEmpty);
    });

    test('the /paywall route also fires paywall_shown', () {
      observer.didPush(route('/paywall'), null);

      expect(logger.named('screen_view'), hasLength(1));
      expect(logger.named('paywall_shown'), hasLength(1));
    });
  });
}
