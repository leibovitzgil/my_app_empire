import 'dart:async';

import 'package:crash_reporting/crash_reporting.dart';
import 'package:feature_auth/feature_auth.dart';

/// Keeps the bound [CrashReporter]'s user association current: whenever the
/// signed-in identity changes, forwards the account's **uid — never the
/// email or any other PII** — to [CrashReporter.setUserId], and clears it
/// (null) on sign-out so a crash after logout is never attributed to the
/// previous user.
///
/// Constructed eagerly in `injection.dart` (like `DirectoryPublisher` and
/// `CurrentUser`) so the account subscription exists before the user can
/// possibly sign in.
class CrashReporterUserBinder {
  /// Creates a [CrashReporterUserBinder], subscribing to [accounts]
  /// immediately.
  CrashReporterUserBinder({
    required CrashReporter reporter,
    required Stream<AuthAccount?> accounts,
  }) : _reporter = reporter {
    _subscription = accounts.listen(
      (account) => unawaited(_reporter.setUserId(account?.uid)),
    );
  }

  final CrashReporter _reporter;
  late final StreamSubscription<AuthAccount?> _subscription;

  /// Releases the account subscription.
  Future<void> dispose() => _subscription.cancel();
}
