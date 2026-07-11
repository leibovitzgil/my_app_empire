import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthFailureMessage', () {
    // One entry per taxonomy kind; the coverage assertion below keeps this
    // list honest when AuthFailureCode grows. (A const map can't key on an
    // Equatable — records instead.)
    const expectations = <(AuthFailure, String?)>[
      (AuthFailure.invalidCredentials(), 'Email or password is incorrect.'),
      (AuthFailure.emailInUse(), 'An account already exists for that email.'),
      (AuthFailure.weakPassword(), 'That password is too weak.'),
      (
        AuthFailure.invalidEmail(),
        "That doesn't look like a valid email address.",
      ),
      (AuthFailure.userDisabled(), 'This account has been disabled.'),
      (AuthFailure.requiresRecentLogin(), 'Please sign in again to continue.'),
      (AuthFailure.network(), 'No connection. Check your network and retry.'),
      (AuthFailure.cancelled(), null),
      (AuthFailure.unknown(), 'Something went wrong. Please try again.'),
    ];

    test('covers every failure kind', () {
      expect(
        expectations.map((entry) => entry.$1.code).toSet(),
        AuthFailureCode.values.toSet(),
      );
    });

    for (final (failure, message) in expectations) {
      test('${failure.code.name} maps to ${message ?? 'no message'}', () {
        expect(failure.message, message);
      });
    }

    test('only a user-initiated cancel is suppressed', () {
      final suppressed = expectations
          .where((entry) => entry.$2 == null)
          .map((entry) => entry.$1.code);
      expect(suppressed, [AuthFailureCode.cancelled]);
    });
  });
}
