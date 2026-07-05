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
  final _displayNameController = StreamController<String?>.broadcast();

  @override
  Stream<String?> get user => _controller.stream;

  /// The signed-in user's display name, alongside [user]'s id — not part of
  /// the shared `AuthRepository` contract (which only models an opaque id;
  /// widening it would ripple into every app/impl on that interface), so
  /// this is Duet-local plumbing consumed only by `CurrentUserName` (see
  /// that file's doc) to replace `feature_library`/`feature_pairing`'s
  /// initials-from-id placeholders with a real name. Mocked here (an email's
  /// local part, or a fixed label for the OAuth flows) since there's no real
  /// identity provider backing this dev-only repository.
  Stream<String?> get displayName => _displayNameController.stream;

  @override
  Future<void> login(String email, String password) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    _controller.add('user_id_123');
    _displayNameController.add(_nameFromEmail(email));
  }

  @override
  Future<void> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    _controller.add('google_user_123');
    _displayNameController.add('Google User');
  }

  @override
  Future<void> signInWithApple() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    _controller.add('apple_user_123');
    _displayNameController.add('Apple User');
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _controller.add(null);
    _displayNameController.add(null);
  }

  /// Derives a friendly display name from an email's local part (e.g.
  /// `jane.doe@example.com` -> `Jane.doe`) — good enough for this mock;
  /// `FirebaseAuthRepository` would read a real `displayName`/`email` off
  /// `firebase_auth.User` instead.
  static String _nameFromEmail(String email) {
    final local = email.split('@').first.trim();
    if (local.isEmpty) return 'Signed-in user';
    return local[0].toUpperCase() + local.substring(1);
  }
}
