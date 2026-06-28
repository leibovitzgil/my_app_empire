import 'dart:async';

import 'package:feature_auth/feature_auth.dart';

/// An in-memory [AuthRepository] so Tandem runs without a real backend. Any
/// email/password "logs in" the current device user.
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<String?>.broadcast();

  @override
  Stream<String?> get user => _controller.stream;

  @override
  Future<void> login(String email, String password) async {
    _controller.add('tandem-user');
  }

  @override
  Future<void> logout() async {
    _controller.add(null);
  }
}
