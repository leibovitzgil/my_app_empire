import 'package:equatable/equatable.dart';

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

  @override
  List<Object?> get props => [uid, email, displayName, emailVerified];
}
