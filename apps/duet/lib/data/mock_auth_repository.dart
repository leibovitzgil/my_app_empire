import 'dart:async';
import 'package:core_utils/core_utils.dart';
import 'package:feature_auth/feature_auth.dart';

/// An in-memory [AuthRepository] for local development.
///
/// Broadcast (unlike a plain, single-subscription controller) because more
/// than one long-lived singleton needs to observe [user]: `AuthBloc` and
/// `CurrentUser` both subscribe independently (each eagerly, at app-startup —
/// see `injection.dart` — so none misses the first emission despite a
/// broadcast stream not replaying past events to a late subscriber).
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

  /// The last emitted account, so [sendEmailVerification] (instant-verify)
  /// and [refreshAccount] can re-emit it.
  AuthAccount? _lastAccount;

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

  void _emitAccount(AuthAccount? account) {
    _lastAccount = account;
    _accountController.add(account);
  }

  @override
  Future<Result<void>> login(String email, String password) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    const uid = 'user_id_123';
    final name = _nameFromEmail(email);
    _controller.add(uid);
    _displayNameController.add(name);
    // Established accounts count as verified, so the verify banner only
    // shows for the fresh sign-up path in local dev.
    _emitAccount(
      AuthAccount(
        uid: uid,
        email: email,
        displayName: name,
        emailVerified: true,
        provider: AuthProviderKind.password,
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    const uid = 'user_id_123';
    final trimmed = displayName?.trim();
    final name = trimmed == null || trimmed.isEmpty
        ? _nameFromEmail(email)
        : trimmed;
    _controller.add(uid);
    _displayNameController.add(name);
    // Fresh sign-ups start unverified — exercises the verify-email banner;
    // the mock's sendEmailVerification instantly verifies.
    _emitAccount(
      AuthAccount(
        uid: uid,
        email: email,
        displayName: name,
        provider: AuthProviderKind.password,
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> updateDisplayName(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final account = _lastAccount;
    if (account == null) {
      return const ResultFailure(AuthFailure.unknown('no-signed-in-user'));
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const ResultFailure(AuthFailure.unknown('empty-display-name'));
    }
    _displayNameController.add(trimmed);
    _emitAccount(
      AuthAccount(
        uid: account.uid,
        email: account.email,
        displayName: trimmed,
        emailVerified: account.emailVerified,
        provider: account.provider,
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> reauthenticate({String? password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const Success(null);
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const Success(null);
  }

  @override
  Future<Result<void>> sendEmailVerification() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final account = _lastAccount;
    if (account == null) {
      return const ResultFailure(AuthFailure.unknown('no-signed-in-user'));
    }
    // Instant-verify: no inbox in local dev, so "sending" the email is the
    // verification.
    _emitAccount(
      AuthAccount(
        uid: account.uid,
        email: account.email,
        displayName: account.displayName,
        emailVerified: true,
        provider: account.provider,
      ),
    );
    return const Success(null);
  }

  @override
  Future<void> refreshAccount() async {
    _emitAccount(_lastAccount);
  }

  @override
  Future<Result<void>> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    const uid = 'google_user_123';
    const name = 'Google User';
    const email = 'google.user@duet.dev';
    _controller.add(uid);
    _displayNameController.add(name);
    _emitAccount(
      const AuthAccount(
        uid: uid,
        email: email,
        displayName: name,
        emailVerified: true,
        provider: AuthProviderKind.google,
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> signInWithApple() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    const uid = 'apple_user_123';
    const name = 'Apple User';
    const email = 'apple.user@duet.dev';
    _controller.add(uid);
    _displayNameController.add(name);
    _emitAccount(
      const AuthAccount(
        uid: uid,
        email: email,
        displayName: name,
        emailVerified: true,
        provider: AuthProviderKind.apple,
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _controller.add(null);
    _displayNameController.add(null);
    _emitAccount(null);
    return const Success(null);
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
