import 'dart:async';
import 'package:core_utils/core_utils.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: AuthRepository)
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<String?>();

  @override
  Stream<String?> get user => _controller.stream;

  @override
  Future<Result<void>> login(String email, String password) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    _controller.add('user_id_123');
    return const Success(null);
  }

  @override
  Future<Result<void>> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    _controller.add('user_id_123');
    return const Success(null);
  }

  @override
  Future<Result<void>> updateDisplayName(String name) async =>
      const Success(null);

  @override
  Future<Result<void>> reauthenticate({String? password}) async =>
      const Success(null);

  @override
  Future<Result<void>> sendPasswordReset(String email) async =>
      const Success(null);

  @override
  Future<Result<void>> sendEmailVerification() async => const Success(null);

  @override
  Future<Result<void>> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    _controller.add('google_user_123');
    return const Success(null);
  }

  @override
  Future<Result<void>> signInWithApple() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    _controller.add('apple_user_123');
    return const Success(null);
  }

  @override
  Future<Result<void>> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _controller.add(null);
    return const Success(null);
  }
}
