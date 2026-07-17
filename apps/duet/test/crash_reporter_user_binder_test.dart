import 'dart:async';

import 'package:crash_reporting/crash_reporting.dart';
import 'package:duet/data/crash_reporter_user_binder.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingCrashReporter implements CrashReporter {
  final List<String?> userIds = <String?>[];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  }) async {}

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> setUserId(String? uid) async {
    userIds.add(uid);
  }
}

void main() {
  late _RecordingCrashReporter reporter;
  late StreamController<AuthAccount?> accounts;
  late CrashReporterUserBinder binder;

  setUp(() {
    reporter = _RecordingCrashReporter();
    accounts = StreamController<AuthAccount?>();
    binder = CrashReporterUserBinder(
      reporter: reporter,
      accounts: accounts.stream,
    );
  });

  tearDown(() async {
    await binder.dispose();
    await accounts.close();
  });

  test('forwards the uid — never the email — on sign-in', () async {
    accounts.add(
      const AuthAccount(
        uid: 'uid-1',
        email: 'jane.doe@example.com',
        displayName: 'Jane',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(reporter.userIds, ['uid-1']);
  });

  test('clears the association (null) on sign-out', () async {
    accounts
      ..add(const AuthAccount(uid: 'uid-1', email: 'jane.doe@example.com'))
      ..add(null);
    await Future<void>.delayed(Duration.zero);

    expect(reporter.userIds, ['uid-1', null]);
  });

  test('tracks identity changes across re-sign-in', () async {
    accounts
      ..add(const AuthAccount(uid: 'uid-1'))
      ..add(null)
      ..add(const AuthAccount(uid: 'uid-2'));
    await Future<void>.delayed(Duration.zero);

    expect(reporter.userIds, ['uid-1', null, 'uid-2']);
  });

  test('dispose releases the subscription — no forwards after it', () async {
    accounts.add(const AuthAccount(uid: 'uid-1'));
    await Future<void>.delayed(Duration.zero);

    await binder.dispose();
    accounts.add(const AuthAccount(uid: 'uid-2'));
    await Future<void>.delayed(Duration.zero);

    expect(reporter.userIds, ['uid-1']);
  });
}
