import 'package:feature_auth/src/domain/auth_failure.dart';

/// UI-side rendering of the domain [AuthFailure] taxonomy: one short, human
/// line per failure kind. Kept out of the domain layer on purpose — copy is
/// presentation, and apps/screens can override it where context demands.
extension AuthFailureMessage on AuthFailure {
  /// A short, human-readable description of this failure, or null when it
  /// should not surface at all (the user cancelled the flow themselves).
  String? get message => switch (code) {
    AuthFailureCode.invalidCredentials => 'Email or password is incorrect.',
    AuthFailureCode.emailInUse => 'An account already exists for that email.',
    AuthFailureCode.weakPassword => 'That password is too weak.',
    AuthFailureCode.invalidEmail =>
      "That doesn't look like a valid email address.",
    AuthFailureCode.userDisabled => 'This account has been disabled.',
    AuthFailureCode.requiresRecentLogin => 'Please sign in again to continue.',
    AuthFailureCode.network => 'No connection. Check your network and retry.',
    AuthFailureCode.cancelled => null,
    AuthFailureCode.unknown => 'Something went wrong. Please try again.',
  };
}
