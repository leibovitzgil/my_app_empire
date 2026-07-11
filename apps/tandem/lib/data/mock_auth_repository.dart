import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:feature_auth/feature_auth.dart';

/// An in-memory [AuthRepository] so Tandem runs without a real backend. Any
/// email/password "logs in" the current device user.
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<String?>.broadcast();

  @override
  Stream<String?> get user => _controller.stream;

  @override
  Future<Result<void>> login(String email, String password) async {
    _controller.add('tandem-user');
    return const Success(null);
  }

  @override
  Future<Result<void>> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    _controller.add('tandem-user');
    return const Success(null);
  }

  @override
  Future<Result<void>> signInWithGoogle() async {
    _controller.add('tandem-google-user');
    return const Success(null);
  }

  @override
  Future<Result<void>> signInWithApple() async {
    _controller.add('tandem-apple-user');
    return const Success(null);
  }

  @override
  Future<Result<void>> logout() async {
    _controller.add(null);
    return const Success(null);
  }
}
