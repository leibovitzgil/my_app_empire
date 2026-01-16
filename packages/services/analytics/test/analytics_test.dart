import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:analytics/analytics.dart';

class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}
class MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}
class MockTalker extends Mock implements Talker {}

void main() {
  late MockFirebaseAnalytics mockAnalytics;
  late MockFirebaseCrashlytics mockCrashlytics;
  late MockTalker mockTalker;
  late AppLogger appLogger;

  setUp(() {
    mockAnalytics = MockFirebaseAnalytics();
    mockCrashlytics = MockFirebaseCrashlytics();
    mockTalker = MockTalker();

    when(() => mockAnalytics.logEvent(name: any(named: 'name'), parameters: any(named: 'parameters')))
        .thenAnswer((_) async {});
    when(() => mockCrashlytics.log(any())).thenAnswer((_) async {});
    when(() => mockCrashlytics.recordError(any(), any(), reason: any(named: 'reason')))
        .thenAnswer((_) async {});
    when(() => mockTalker.info(any())).thenAnswer((_) {});
    when(() => mockTalker.warning(any())).thenAnswer((_) {});
    when(() => mockTalker.error(any(), any(), any())).thenAnswer((_) {});

    appLogger = AppLogger(
      analytics: mockAnalytics,
      crashlytics: mockCrashlytics,
      talker: mockTalker,
    );
  });

  test('logEvent calls analytics and talker', () async {
    await appLogger.logEvent('test_event', {'param': 1});

    verify(() => mockTalker.info(any(that: contains('test_event')))).called(1);
    verify(() => mockAnalytics.logEvent(name: 'test_event', parameters: {'param': 1})).called(1);
  });

  test('logInfo calls talker and crashlytics log', () {
    appLogger.logInfo('info message');

    verify(() => mockTalker.info('info message')).called(1);
    verify(() => mockCrashlytics.log('info message')).called(1);
  });

  test('logError calls talker and crashlytics recordError', () async {
    final exception = Exception('oops');
    await appLogger.logError('error message', exception);

    verify(() => mockTalker.error('error message', exception, any())).called(1);
    verify(() => mockCrashlytics.recordError(exception, any(), reason: 'error message')).called(1);
  });
}
