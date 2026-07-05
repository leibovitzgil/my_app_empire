import 'package:feature_auth/src/domain/auth_account.dart';
import 'package:feature_auth/src/domain/auth_account_provider.dart';
import 'package:feature_auth/src/domain/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart' show kIsWeb;

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
    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) return null;
      return AuthAccount(
        uid: firebaseUser.uid,
        email: firebaseUser.email,
        displayName: firebaseUser.displayName,
      );
    });
  }

  @override
  Future<void> login(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signInWithGoogle() {
    return _signInWithProvider(firebase_auth.GoogleAuthProvider());
  }

  @override
  Future<void> signInWithApple() {
    return _signInWithProvider(firebase_auth.AppleAuthProvider());
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
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }
}
