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
      );
    });
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
