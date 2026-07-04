import 'dart:async';
import 'package:feature_auth/feature_auth.dart';

/// An in-memory [AuthRepository] for local development.
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<String?>();

  @override
  Stream<String?> get user => _controller.stream;

  @override
  Future<void> login(String email, String password) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    _controller.add('user_id_123');
  }

  @override
  Future<void> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    _controller.add('google_user_123');
  }

  @override
  Future<void> signInWithApple() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    _controller.add('apple_user_123');
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _controller.add(null);
  }
}
