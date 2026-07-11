import 'package:core_utils/core_utils.dart';
import 'package:feature_auth/src/domain/auth_account.dart';
import 'package:feature_auth/src/domain/auth_account_provider.dart';
import 'package:feature_auth/src/domain/auth_failure.dart';
import 'package:feature_auth/src/domain/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

/// Maps a [firebase_auth.FirebaseAuthException]'s `code` onto the domain
/// [AuthFailure] taxonomy.
///
/// Unrecognized codes come back as [AuthFailure.unknown] carrying the code,
/// so nothing user-facing ever renders a raw Firebase string. Visible only
/// so tests can pin the mapping per code — everything else goes through the
/// repository, which applies it in [FirebaseAuthRepository._guard].
@visibleForTesting
AuthFailure mapFirebaseAuthCode(String code) {
  return switch (code) {
    // Firebase deliberately collapses wrong-password/user-not-found into
    // invalid-credential on newer backends; older ones still emit the
    // specific codes.
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'INVALID_LOGIN_CREDENTIALS' => const AuthFailure.invalidCredentials(),
    'email-already-in-use' => const AuthFailure.emailInUse(),
    'weak-password' => const AuthFailure.weakPassword(),
    'invalid-email' => const AuthFailure.invalidEmail(),
    'user-disabled' => const AuthFailure.userDisabled(),
    'requires-recent-login' => const AuthFailure.requiresRecentLogin(),
    'network-request-failed' => const AuthFailure.network(),
    // Cancel codes differ per platform/flow: web popups, native provider
    // sheets, and sign_in_with_apple each spell it differently.
    'canceled' ||
    'cancelled' ||
    'user-cancelled' ||
    'popup-closed-by-user' ||
    'web-context-canceled' ||
    'web-context-cancelled' => const AuthFailure.cancelled(),
    _ => AuthFailure.unknown(code),
  };
}

class FirebaseAuthRepository implements AuthRepository, AuthAccountProvider {
  FirebaseAuthRepository({firebase_auth.FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance;

  final firebase_auth.FirebaseAuth _firebaseAuth;

  @override
  Stream<String?> get user {
    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      return firebaseUser?.uid;
    });
  }

  @override
  Stream<AuthAccount?> get account {
    // userChanges (not authStateChanges): a superset that also fires on
    // profile mutations, so a display name set right after sign-up (or
    // edited later, M1.5) reaches account listeners — notably Duet's
    // directory upsert — without bespoke re-emission plumbing.
    return _firebaseAuth.userChanges().map((firebaseUser) {
      if (firebaseUser == null) return null;
      return AuthAccount(
        uid: firebaseUser.uid,
        email: firebaseUser.email,
        displayName: firebaseUser.displayName,
        emailVerified: firebaseUser.emailVerified,
        provider: _providerKindOf(firebaseUser),
      );
    });
  }

  /// Maps the linked providers onto the domain kind, preferring the
  /// password credential when several are linked (cheapest re-auth UX).
  static AuthProviderKind _providerKindOf(firebase_auth.User user) {
    final ids = user.providerData.map((info) => info.providerId).toSet();
    if (ids.contains('password')) return AuthProviderKind.password;
    if (ids.contains('google.com')) return AuthProviderKind.google;
    if (ids.contains('apple.com')) return AuthProviderKind.apple;
    return AuthProviderKind.unknown;
  }

  @override
  Future<void> refreshAccount() async {
    // reload() re-reads the profile server-side and makes userChanges
    // re-emit — how a verification completed in the user's inbox reaches
    // the account stream after the app resumes.
    await _firebaseAuth.currentUser?.reload();
  }

  @override
  Future<Result<void>> login(String email, String password) {
    return _guard(
      () => _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );
  }

  @override
  Future<Result<void>> signUp(
    String email,
    String password, {
    String? displayName,
  }) {
    return _guard(() async {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final name = displayName?.trim();
      if (name == null || name.isEmpty) return;
      final user = credential.user;
      if (user == null) return;
      await user.updateDisplayName(name);
      // Refresh the cached profile so the userChanges emission carries the
      // name (updateDisplayName alone updates the backend, not the local
      // User snapshot on all platforms).
      await user.reload();
    });
  }

  @override
  Future<Result<void>> signInWithGoogle() {
    return _guard(
      () => _signInWithProvider(firebase_auth.GoogleAuthProvider()),
    );
  }

  @override
  Future<Result<void>> signInWithApple() {
    return _guard(() => _signInWithProvider(firebase_auth.AppleAuthProvider()));
  }

  /// Runs an OAuth provider flow, using the popup flow on web and the native
  /// provider flow on mobile.
  Future<void> _signInWithProvider(firebase_auth.AuthProvider provider) async {
    if (kIsWeb) {
      await _firebaseAuth.signInWithPopup(provider);
    } else {
      await _firebaseAuth.signInWithProvider(provider);
    }
  }

  @override
  Future<Result<void>> updateDisplayName(String name) {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return Future.value(
        const ResultFailure(AuthFailure.unknown('no-signed-in-user')),
      );
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return Future.value(
        const ResultFailure(AuthFailure.unknown('empty-display-name')),
      );
    }
    return _guard(() async {
      await user.updateDisplayName(trimmed);
      // Refresh the cached profile so userChanges re-emits with the new
      // name (same reasoning as signUp's post-update reload).
      await user.reload();
    });
  }

  @override
  Future<Result<void>> reauthenticate({String? password}) {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return Future.value(
        const ResultFailure(AuthFailure.unknown('no-signed-in-user')),
      );
    }
    return _guard(() async {
      if (password != null) {
        final email = user.email;
        if (email == null) {
          // A password credential can't exist without an email — the caller
          // picked the wrong path for this account.
          throw firebase_auth.FirebaseAuthException(
            code: 'invalid-credential',
          );
        }
        await user.reauthenticateWithCredential(
          firebase_auth.EmailAuthProvider.credential(
            email: email,
            password: password,
          ),
        );
        return;
      }
      final provider = switch (_providerKindOf(user)) {
        AuthProviderKind.google => firebase_auth.GoogleAuthProvider(),
        AuthProviderKind.apple => firebase_auth.AppleAuthProvider(),
        // A password (or unknown) account has no provider flow to re-run;
        // the caller should have collected a password.
        AuthProviderKind.password ||
        AuthProviderKind.unknown => throw firebase_auth.FirebaseAuthException(
          code: 'invalid-credential',
        ),
      };
      // Same platform split as _signInWithProvider: popup on web, native
      // provider flow elsewhere.
      if (kIsWeb) {
        await user.reauthenticateWithPopup(provider);
      } else {
        await user.reauthenticateWithProvider(provider);
      }
    });
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) {
    return _guard(() => _firebaseAuth.sendPasswordResetEmail(email: email));
  }

  @override
  Future<Result<void>> sendEmailVerification() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return Future.value(
        const ResultFailure(AuthFailure.unknown('no-signed-in-user')),
      );
    }
    return _guard(user.sendEmailVerification);
  }

  @override
  Future<Result<void>> logout() {
    return _guard(_firebaseAuth.signOut);
  }

  /// Runs [action], translating thrown Firebase errors into the domain
  /// taxonomy so no exception crosses the repository boundary (G4).
  Future<Result<void>> _guard(Future<void> Function() action) async {
    try {
      await action();
      return const Success(null);
    } on firebase_auth.FirebaseAuthException catch (error, stackTrace) {
      return ResultFailure(mapFirebaseAuthCode(error.code), stackTrace);
    } on Object catch (error, stackTrace) {
      return ResultFailure(AuthFailure.unknown(error), stackTrace);
    }
  }
}
