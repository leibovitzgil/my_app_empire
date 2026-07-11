import 'package:equatable/equatable.dart';

/// How a signed-in account authenticates — which credential a
/// re-authentication flow must collect (see `AuthRepository.reauthenticate`
/// and `ReauthDialog`).
enum AuthProviderKind {
  /// Email + password.
  password,

  /// Google OAuth.
  google,

  /// Sign in with Apple.
  apple,

  /// Unrecognized/unavailable (e.g. a mock without provider data).
  unknown,
}

/// A signed-in identity's account details (email, display name), alongside
/// the bare user id `AuthRepository.user` already emits.
///
/// Kept as a sibling contract (see `AuthAccountProvider`) rather than
/// widening `AuthRepository` itself, so apps that only ever needed the bare
/// id (`app_template`, `showcase`, ...) are unaffected by features (e.g.
/// `duet`'s collaborator invites) that need an email to resolve against a
/// directory.
class AuthAccount extends Equatable {
  /// Creates an [AuthAccount].
  const AuthAccount({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = false,
    this.provider = AuthProviderKind.unknown,
  });

  /// The signed-in account's id.
  final String uid;

  /// The account's email, if known.
  final String? email;

  /// The account's display name, if known.
  final String? displayName;

  /// Whether the account's email address has been verified. Rides the
  /// `account` stream (refreshed via `AuthAccountProvider.refreshAccount`)
  /// so UI like the verify-email banner can react; nothing gates on it in
  /// 1.0 and security rules never depend on it.
  final bool emailVerified;

  /// How this account authenticates — what a re-authentication flow must
  /// collect (password entry vs. re-running an OAuth provider).
  final AuthProviderKind provider;

  @override
  List<Object?> get props => [uid, email, displayName, emailVerified, provider];
}
