import 'dart:async';
import 'package:feature_auth/feature_auth.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: AuthRepository)
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<String?>();

  @override
  Stream<String?> get user => _controller.stream;

  @override
  Future<void> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    _controller.add('user_id_123');
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _controller.add(null);
  }
}
