// Unit-covers `CallableAccountPurge`'s error mapping — the boundary that
// folds `FirebaseFunctionsException` codes onto the shared `AuthFailure`
// taxonomy so the Settings deletion flow can pattern-match them (mirrors
// `feature_auth`'s `mapFirebaseAuthCode` table test). The happy path and
// the whole re-auth/retry sequence are covered against a fake in
// `duet_settings_page_test.dart`; this pins the code translation itself.
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:duet/data/callable_account_purge.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

FirebaseFunctionsException _exception(String code) =>
    FirebaseFunctionsException(message: code, code: code);

void main() {
  group('mapCallableError', () {
    const cases = <(String, AuthFailureCode)>[
      ('failed-precondition', AuthFailureCode.requiresRecentLogin),
      ('unauthenticated', AuthFailureCode.requiresRecentLogin),
      ('unavailable', AuthFailureCode.network),
      ('deadline-exceeded', AuthFailureCode.network),
      ('internal', AuthFailureCode.unknown),
      ('not-found', AuthFailureCode.unknown),
    ];

    for (final (code, expected) in cases) {
      test('$code -> ${expected.name}', () {
        final failure = mapCallableError(_exception(code));
        expect(failure.code, expected);
      });
    }

    test('a non-Functions error maps to unknown, keeping the raw error', () {
      final raw = StateError('boom');
      final failure = mapCallableError(raw);
      expect(failure.code, AuthFailureCode.unknown);
      expect(failure.raw, same(raw));
    });
  });
}
