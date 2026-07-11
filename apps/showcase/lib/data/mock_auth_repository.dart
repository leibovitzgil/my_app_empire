import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:feature_auth/feature_auth.dart';

/// An in-memory [AuthRepository] so the showcase runs without a real backend.
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<String?>.broadcast();

  @override
  Stream<String?> get user => _controller.stream;

  @override
  Future<Result<void>> login(String email, String password) async {
    _controller.add('showcase-user');
    return const Success(null);
  }

  @override
  Future<Result<void>> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    _controller.add('showcase-user');
    return const Success(null);
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) async =>
      const Success(null);

  @override
  Future<Result<void>> sendEmailVerification() async => const Success(null);

  @override
  Future<Result<void>> signInWithGoogle() async {
    _controller.add('showcase-google-user');
    return const Success(null);
  }

  @override
  Future<Result<void>> signInWithApple() async {
    _controller.add('showcase-apple-user');
    return const Success(null);
  }

  @override
  Future<Result<void>> logout() async {
    _controller.add(null);
    return const Success(null);
  }
}
