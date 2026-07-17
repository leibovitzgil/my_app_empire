import 'dart:async';

import 'package:crash_reporting/src/crash_reporter.dart';
import 'package:flutter/foundation.dart';

/// Routes Flutter's two global error funnels into [reporter]:
///
/// - [FlutterError.onError] — framework errors (build/layout/paint and
///   anything else the framework catches). The previous handler (by
///   default the console dump) keeps running first, so local visibility
///   is unchanged.
/// - [PlatformDispatcher.onError] — uncaught asynchronous errors from
///   the root zone.
///
/// Call this from *real* Firebase entry points only, right after DI wires
/// a `CrashlyticsCrashReporter`. Mock/emulator/headless entry points bind
/// a `NoopCrashReporter` and never call this — the default handlers stay
/// untouched there (G2: the headless gate never constructs Firebase, and
/// tests keep Flutter's own error reporting semantics).
void installCrashHooks(CrashReporter reporter) {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    previousOnError?.call(details);
    unawaited(
      reporter.recordError(
        details.exception,
        details.stack,
        fatal: true,
        context: details.context?.toDescription(),
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(reporter.recordError(error, stack, fatal: true));
    return true;
  };
}
