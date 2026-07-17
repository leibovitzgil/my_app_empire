import 'package:crash_reporting/crash_reporting.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'fake_crash_reporter.dart';

class MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

void main() {
  group('FakeCrashReporter (contract shape)', () {
    test('captures recordError with fatal and context', () async {
      final reporter = FakeCrashReporter();
      final error = Exception('boom');
      final stack = StackTrace.current;

      await reporter.recordError(
        error,
        stack,
        fatal: true,
        context: 'while rendering',
      );

      expect(reporter.recordedErrors, hasLength(1));
      final recorded = reporter.recordedErrors.single;
      expect(recorded.error, same(error));
      expect(recorded.stack, same(stack));
      expect(recorded.fatal, isTrue);
      expect(recorded.context, 'while rendering');
    });

    test('captures log and setUserId', () async {
      final reporter = FakeCrashReporter();

      await reporter.log('breadcrumb');
      await reporter.setUserId('uid-1');
      await reporter.setUserId(null);

      expect(reporter.loggedMessages, ['breadcrumb']);
      expect(reporter.userIds, ['uid-1', null]);
    });
  });

  group('NoopCrashReporter', () {
    test('every call completes without side effects', () async {
      const reporter = NoopCrashReporter();

      await reporter.recordError(
        Exception('ignored'),
        StackTrace.current,
        fatal: true,
        context: 'ignored',
      );
      await reporter.log('ignored');
      await reporter.setUserId('ignored');
      await reporter.setUserId(null);
    });
  });

  group('CrashlyticsCrashReporter', () {
    late MockFirebaseCrashlytics crashlytics;
    late CrashlyticsCrashReporter reporter;

    setUp(() {
      crashlytics = MockFirebaseCrashlytics();
      reporter = CrashlyticsCrashReporter(crashlytics: crashlytics);

      when(
        () => crashlytics.recordError(
          any<Object>(),
          any<StackTrace?>(),
          reason: any<Object?>(named: 'reason'),
          fatal: any<bool>(named: 'fatal'),
        ),
      ).thenAnswer((_) async {});
      when(() => crashlytics.log(any<String>())).thenAnswer((_) async {});
      when(
        () => crashlytics.setUserIdentifier(any<String>()),
      ).thenAnswer((_) async {});
    });

    test('recordError delegates error/stack/fatal/context', () async {
      final error = Exception('boom');
      final stack = StackTrace.current;

      await reporter.recordError(
        error,
        stack,
        fatal: true,
        context: 'while syncing',
      );

      verify(
        () => crashlytics.recordError(
          error,
          stack,
          reason: 'while syncing',
          fatal: true,
        ),
      ).called(1);
    });

    test('recordError defaults to non-fatal with no reason', () async {
      final error = Exception('boom');

      await reporter.recordError(error, null);

      verify(() => crashlytics.recordError(error, null)).called(1);
    });

    test('log delegates the message', () async {
      await reporter.log('breadcrumb');

      verify(() => crashlytics.log('breadcrumb')).called(1);
    });

    test('setUserId delegates the uid', () async {
      await reporter.setUserId('uid-1');

      verify(() => crashlytics.setUserIdentifier('uid-1')).called(1);
    });

    test('setUserId(null) clears via the empty string', () async {
      await reporter.setUserId(null);

      verify(() => crashlytics.setUserIdentifier('')).called(1);
    });
  });
}
