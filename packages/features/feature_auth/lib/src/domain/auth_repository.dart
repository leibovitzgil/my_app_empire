import 'package:core_utils/core_utils.dart';

/// The auth contract apps bind at the DI layer.
///
/// Mutating methods never throw: failures come back as a `ResultFailure`
/// whose `error` is an `AuthFailure` from the domain taxonomy
/// (`auth_failure.dart`), so blocs fold them into state instead of catching.
abstract class AuthRepository {
  /// Emits the current user's id, or null when signed out.
  Stream<String?> get user;

  /// Signs in with an email and password.
  Future<Result<void>> login(String email, String password);

  /// Creates a new account with an email and password, optionally setting
  /// [displayName] on the fresh profile. On success the new user is signed
  /// in and emitted on [user].
  Future<Result<void>> signUp(
    String email,
    String password, {
    String? displayName,
  });

  /// Starts the Google OAuth flow; on success the signed-in user is emitted on
  /// [user].
  Future<Result<void>> signInWithGoogle();

  /// Starts the "Sign in with Apple" flow; on success the signed-in user is
  /// emitted on [user].
  Future<Result<void>> signInWithApple();

  /// Sends a password-reset email to [email]. Succeeds without revealing
  /// whether an account exists (backends suppress enumeration).
  Future<Result<void>> sendPasswordReset(String email);

  /// Sends a verification email to the signed-in account's address. Fails
  /// with an `AuthFailure` when no user is signed in.
  Future<Result<void>> sendEmailVerification();

  /// Signs out.
  Future<Result<void>> logout();
}
