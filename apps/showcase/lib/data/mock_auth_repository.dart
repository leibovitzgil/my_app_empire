import 'dart:async';

import 'package:feature_auth/feature_auth.dart';

/// An in-memory [AuthRepository] so the showcase runs without a real backend.
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<String?>.broadcast();

  @override
  Stream<String?> get user => _controller.stream;

  @override
  Future<void> login(String email, String password) async {
    _controller.add('showcase-user');
  }

  @override
  Future<void> signInWithGoogle() async {
    _controller.add('showcase-google-user');
  }

  @override
  Future<void> signInWithApple() async {
    _controller.add('showcase-apple-user');
  }

  @override
  Future<void> logout() async {
    _controller.add(null);
  }
}
