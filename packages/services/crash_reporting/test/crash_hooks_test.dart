import 'dart:ui';

import 'package:crash_reporting/crash_reporting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_crash_reporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCrashReporter reporter;
  late FlutterExceptionHandler? originalOnError;
  late ErrorCallback? originalPlatformOnError;

  setUp(() {
    reporter = FakeCrashReporter();
    originalOnError = FlutterError.onError;
    originalPlatformOnError = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = originalOnError;
    PlatformDispatcher.instance.onError = originalPlatformOnError;
  });

  group('installCrashHooks', () {
    test(
      'FlutterError.onError records a fatal error with the context '
      'description and still calls the previous handler',
      () async {
        final previousCalls = <FlutterErrorDetails>[];
        FlutterError.onError = previousCalls.add;
        installCrashHooks(reporter);

        final exception = StateError('render failed');
        final stack = StackTrace.current;
        FlutterError.onError!(
          FlutterErrorDetails(
            exception: exception,
            stack: stack,
            context: ErrorDescription('building Widget'),
          ),
        );

        expect(reporter.recordedErrors, hasLength(1));
        final recorded = reporter.recordedErrors.single;
        expect(recorded.error, same(exception));
        expect(recorded.stack, same(stack));
        expect(recorded.fatal, isTrue);
        expect(recorded.context, 'building Widget');
        // The pre-existing handler (normally the console dump) still ran.
        expect(previousCalls, hasLength(1));
        expect(previousCalls.single.exception, same(exception));
      },
    );

    test(
      'PlatformDispatcher.onError records a fatal error and reports the '
      'error as handled',
      () async {
        installCrashHooks(reporter);

        final exception = Exception('uncaught async');
        final stack = StackTrace.current;
        final handled = PlatformDispatcher.instance.onError!(
          exception,
          stack,
        );

        expect(handled, isTrue);
        expect(reporter.recordedErrors, hasLength(1));
        final recorded = reporter.recordedErrors.single;
        expect(recorded.error, same(exception));
        expect(recorded.stack, same(stack));
        expect(recorded.fatal, isTrue);
        expect(recorded.context, isNull);
      },
    );
  });
}
