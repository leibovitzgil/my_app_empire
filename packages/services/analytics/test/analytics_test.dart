import 'package:analytics/analytics.dart';
import 'package:crash_reporting/crash_reporting.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker_flutter/talker_flutter.dart';

class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

class MockCrashReporter extends Mock implements CrashReporter {}

class MockTalker extends Mock implements Talker {}

void main() {
  late MockFirebaseAnalytics mockAnalytics;
  late MockCrashReporter mockCrashReporter;
  late MockTalker mockTalker;
  late AppLogger appLogger;

  setUp(() {
    mockAnalytics = MockFirebaseAnalytics();
    mockCrashReporter = MockCrashReporter();
    mockTalker = MockTalker();

    when(
      () => mockAnalytics.logEvent(
        name: any<String>(named: 'name'),
        parameters: any<Map<String, Object>?>(named: 'parameters'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockCrashReporter.log(any<String>())).thenAnswer((_) async {});
    when(
      () => mockCrashReporter.recordError(
        any<Object>(),
        any<StackTrace?>(),
        fatal: any<bool>(named: 'fatal'),
        context: any<String?>(named: 'context'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockTalker.info(any<dynamic>())).thenAnswer((_) {});
    when(() => mockTalker.warning(any<dynamic>())).thenAnswer((_) {});
    when(
      () =>
          mockTalker.error(any<dynamic>(), any<Object?>(), any<StackTrace?>()),
    ).thenAnswer((_) {});

    appLogger = AppLogger(
      analytics: mockAnalytics,
      crashReporter: mockCrashReporter,
      talker: mockTalker,
    );
  });

  test('logEvent calls analytics and talker', () async {
    await appLogger.logEvent('test_event', {'param': 1});

    verify(
      () => mockTalker.info(any<dynamic>(that: contains('test_event'))),
    ).called(1);
    verify(
      () =>
          mockAnalytics.logEvent(name: 'test_event', parameters: {'param': 1}),
    ).called(1);
  });

  test('logInfo calls talker and the crash reporter log', () {
    appLogger.logInfo('info message');

    verify(() => mockTalker.info('info message')).called(1);
    verify(() => mockCrashReporter.log('info message')).called(1);
  });

  test('logWarning calls talker and prefixes the breadcrumb', () {
    appLogger.logWarning('warn message');

    verify(() => mockTalker.warning('warn message')).called(1);
    verify(() => mockCrashReporter.log('WARNING: warn message')).called(1);
  });

  test('logError calls talker and the crash reporter recordError', () async {
    final exception = Exception('oops');
    await appLogger.logError('error message', exception);

    verify(() => mockTalker.error('error message', exception, any())).called(1);
    verify(
      () => mockCrashReporter.recordError(
        exception,
        any(),
        context: 'error message',
      ),
    ).called(1);
  });

  test('logError without an exception records the message itself', () async {
    await appLogger.logError('bare message');

    verify(
      () => mockCrashReporter.recordError(
        'bare message',
        null,
        context: 'bare message',
      ),
    ).called(1);
  });

  test(
    'with no analytics backend, logEvent is Talker-only and never throws '
    '(the Firebase-free default, safe for headless/mock compositions)',
    () async {
      final localOnly = AppLogger(
        crashReporter: mockCrashReporter,
        talker: mockTalker,
      );

      await localOnly.logEvent('local_event', {'k': 'v'});

      verify(
        () => mockTalker.info(any<dynamic>(that: contains('local_event'))),
      ).called(1);
      verifyNever(
        () => mockAnalytics.logEvent(
          name: any<String>(named: 'name'),
          parameters: any<Map<String, Object>?>(named: 'parameters'),
        ),
      );
    },
  );
}
