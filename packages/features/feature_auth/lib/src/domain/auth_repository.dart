abstract class AuthRepository {
  /// Emits the current user's id, or null when signed out.
  Stream<String?> get user;

  /// Signs in with an email and password.
  Future<void> login(String email, String password);

  /// Starts the Google OAuth flow; on success the signed-in user is emitted on
  /// [user].
  Future<void> signInWithGoogle();

  /// Starts the "Sign in with Apple" flow; on success the signed-in user is
  /// emitted on [user].
  Future<void> signInWithApple();

  /// Signs out.
  Future<void> logout();
}
