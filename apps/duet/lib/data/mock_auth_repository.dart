import 'dart:async';
import 'package:feature_auth/feature_auth.dart';

/// An in-memory [AuthRepository] for local development.
///
/// Broadcast (unlike a plain, single-subscription controller) because more
/// than one long-lived singleton needs to observe [user]: `AuthBloc`,
/// `CurrentUser`, and `UserRoleRepository` all subscribe independently (each
/// eagerly, at app-startup — see `injection.dart` — so none misses the first
/// emission despite a broadcast stream not replaying past events to a late
/// subscriber).
///
/// Also implements [AuthAccountProvider] — mirroring
/// `FirebaseAuthRepository` — so the default (headless, no-Firebase) DI
/// branch can source `CurrentUserName`/`CurrentUserEmail` (and
/// `feature_pairing`'s email-invite path) from the same seam the real
/// Firebase-backed identity uses, rather than a Duet-only side channel.
class MockAuthRepository implements AuthRepository, AuthAccountProvider {
  final _controller = StreamController<String?>.broadcast();
  final _displayNameController = StreamController<String?>.broadcast();
  final _accountController = StreamController<AuthAccount?>.broadcast();

  @override
  Stream<String?> get user => _controller.stream;

  /// The signed-in user's display name, alongside [user]'s id — not part of
  /// the shared `AuthRepository` contract (which only models an opaque id;
  /// widening it would ripple into every app/impl on that interface), so
  /// this is Duet-local plumbing consumed only by `CurrentUserName` (see
  /// that file's doc) to replace `feature_library`/`feature_pairing`'s
  /// initials-from-id placeholders with a real name. Mocked here (an email's
  /// local part, or a fixed label for the OAuth flows) since there's no real
  /// identity provider backing this dev-only repository.
  Stream<String?> get displayName => _displayNameController.stream;

  @override
  Stream<AuthAccount?> get account => _accountController.stream;

  @override
  Future<void> login(String email, String password) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    const uid = 'user_id_123';
    final name = _nameFromEmail(email);
    _controller.add(uid);
    _displayNameController.add(name);
    _accountController.add(
      AuthAccount(uid: uid, email: email, displayName: name),
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    const uid = 'google_user_123';
    const name = 'Google User';
    const email = 'google.user@duet.dev';
    _controller.add(uid);
    _displayNameController.add(name);
    _accountController.add(
      const AuthAccount(uid: uid, email: email, displayName: name),
    );
  }

  @override
  Future<void> signInWithApple() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    const uid = 'apple_user_123';
    const name = 'Apple User';
    const email = 'apple.user@duet.dev';
    _controller.add(uid);
    _displayNameController.add(name);
    _accountController.add(
      const AuthAccount(uid: uid, email: email, displayName: name),
    );
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _controller.add(null);
    _displayNameController.add(null);
    _accountController.add(null);
  }

  /// Derives a friendly display name from an email's local part (e.g.
  /// `jane.doe@example.com` -> `Jane.doe`) — good enough for this mock;
  /// `FirebaseAuthRepository` would read a real `displayName`/`email` off
  /// `firebase_auth.User` instead.
  static String _nameFromEmail(String email) {
    final local = email.split('@').first.trim();
    if (local.isEmpty) return 'Signed-in user';
    return local[0].toUpperCase() + local.substring(1);
  }
}
