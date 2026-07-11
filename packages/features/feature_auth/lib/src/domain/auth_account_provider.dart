import 'package:feature_auth/src/domain/auth_account.dart';

/// Sibling contract to `AuthRepository` for identity sources that can
/// surface a full [AuthAccount] (email, display name), not just a bare user
/// id. Kept separate so apps that only need `AuthRepository.user` are
/// unaffected — see `FirebaseAuthRepository`, which implements both.
abstract class AuthAccountProvider {
  /// Emits the current signed-in [AuthAccount], or null when signed out.
  Stream<AuthAccount?> get account;

  /// Re-reads the signed-in profile from the backend so [account] re-emits
  /// with fresh fields — notably [AuthAccount.emailVerified], which only
  /// changes server-side (the user clicks the link in their inbox). UI
  /// calls this on app resume; a no-op when signed out.
  Future<void> refreshAccount();
}
