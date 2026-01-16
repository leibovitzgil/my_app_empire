import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
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
  Future<void> login(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }
}
