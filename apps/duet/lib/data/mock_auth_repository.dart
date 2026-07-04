import 'dart:async';
import 'package:feature_auth/feature_auth.dart';

/// An in-memory [AuthRepository] for local development.
///
/// Broadcast (unlike a plain, single-subscription controller) because more
/// than one long-lived singleton needs to observe [user]: `AuthBloc`,
/// `CurrentUser`, and `UserRoleRepository` all subscribe independently (each
/// eagerly, at app-startup — see `injection.dart` — so none misses the first
/// emission despite a broadcast stream not replaying past events to a late
/// subscriber).
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<String?>.broadcast();

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
