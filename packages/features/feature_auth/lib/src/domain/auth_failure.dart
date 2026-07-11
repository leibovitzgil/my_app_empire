import 'package:equatable/equatable.dart';

/// The kinds of authentication failure the domain distinguishes.
///
/// Backend-specific error codes (e.g. `FirebaseAuthException.code`) are mapped
/// onto this taxonomy at the repository boundary, so blocs and UI never see a
/// raw provider error.
enum AuthFailureCode {
  /// The email/password pair didn't match an account (covers wrong password
  /// and unknown user — indistinguishable on purpose, per anti-enumeration
  /// backend behavior).
  invalidCredentials,

  /// An account already exists for the email (sign-up).
  emailInUse,

  /// The chosen password is too weak (sign-up / password change).
  weakPassword,

  /// The email address is malformed.
  invalidEmail,

  /// The account exists but has been disabled.
  userDisabled,

  /// The operation needs a fresh credential; re-authenticate and retry.
  requiresRecentLogin,

  /// A connectivity problem — retryable.
  network,

  /// The user cancelled the flow (e.g. dismissed the OAuth sheet).
  cancelled,

  /// Anything not classified above; [AuthFailure.raw] carries the original
  /// error for diagnostics.
  unknown,
}

/// A typed authentication failure.
///
/// Carried as the error inside a `ResultFailure` returned by
/// `AuthRepository` methods, and surfaced on `AuthState.failure`. Rendering
/// (human copy per [code]) lives UI-side — see `AuthFailureMessage`.
final class AuthFailure extends Equatable {
  const AuthFailure._(this.code, [this.raw]);

  /// See [AuthFailureCode.invalidCredentials].
  const AuthFailure.invalidCredentials()
    : this._(AuthFailureCode.invalidCredentials);

  /// See [AuthFailureCode.emailInUse].
  const AuthFailure.emailInUse() : this._(AuthFailureCode.emailInUse);

  /// See [AuthFailureCode.weakPassword].
  const AuthFailure.weakPassword() : this._(AuthFailureCode.weakPassword);

  /// See [AuthFailureCode.invalidEmail].
  const AuthFailure.invalidEmail() : this._(AuthFailureCode.invalidEmail);

  /// See [AuthFailureCode.userDisabled].
  const AuthFailure.userDisabled() : this._(AuthFailureCode.userDisabled);

  /// See [AuthFailureCode.requiresRecentLogin].
  const AuthFailure.requiresRecentLogin()
    : this._(AuthFailureCode.requiresRecentLogin);

  /// See [AuthFailureCode.network].
  const AuthFailure.network() : this._(AuthFailureCode.network);

  /// See [AuthFailureCode.cancelled].
  const AuthFailure.cancelled() : this._(AuthFailureCode.cancelled);

  /// An unclassified failure, optionally carrying the original [raw] error.
  const AuthFailure.unknown([Object? raw])
    : this._(AuthFailureCode.unknown, raw);

  /// Which kind of failure this is.
  final AuthFailureCode code;

  /// The original error, kept for diagnostics when [code] is
  /// [AuthFailureCode.unknown]; never shown to users.
  final Object? raw;

  @override
  List<Object?> get props => [code, raw];

  @override
  String toString() =>
      'AuthFailure(${code.name}${raw != null ? ', raw: $raw' : ''})';
}
