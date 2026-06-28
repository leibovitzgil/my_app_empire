import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Emits a user id on [login] and null on [logout], like a real backend.
class LoginEmittingAuthRepository implements AuthRepository {
  final _controller = StreamController<String?>.broadcast();

  @override
  Stream<String?> get user => _controller.stream;

  @override
  Future<void> login(String email, String password) async {
    _controller.add('user_id');
  }

  @override
  Future<void> signInWithGoogle() async {
    _controller.add('google_user_id');
  }

  @override
  Future<void> signInWithApple() async {
    _controller.add('apple_user_id');
  }

  @override
  Future<void> logout() async {
    _controller.add(null);
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({Stream<String?>? userStream})
    : _userStream = userStream ?? const Stream.empty();
  final Stream<String?> _userStream;

  @override
  Stream<String?> get user => _userStream;

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithApple() async {}

  @override
  Future<void> logout() async {}
}

/// Records which sign-in method was invoked and fails the flow, so we can
/// assert the bloc surfaces provider errors as [AuthState.failure].
class ThrowingAuthRepository implements AuthRepository {
  @override
  Stream<String?> get user => const Stream.empty();

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> signInWithGoogle() async {
    throw Exception('google failed');
  }

  @override
  Future<void> signInWithApple() async {
    throw Exception('apple failed');
  }

  @override
  Future<void> logout() async {}
}

void main() {
  group('AuthBloc', () {
    test('initial state is unknown', () {
      expect(
        AuthBloc(authRepository: FakeAuthRepository()).state,
        const AuthState.unknown(),
      );
    });

    blocTest<AuthBloc, AuthState>(
      'emits [unauthenticated] when user stream emits null',
      build: () => AuthBloc(
        authRepository: FakeAuthRepository(
          userStream: Stream.value(null),
        ),
      ),
      expect: () => [const AuthState.unauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [authenticated] when user stream emits a user',
      build: () => AuthBloc(
        authRepository: FakeAuthRepository(
          userStream: Stream.value('user'),
        ),
      ),
      expect: () => [const AuthState.authenticated('user')],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [authenticated] after AuthLoginRequested succeeds',
      build: () => AuthBloc(authRepository: LoginEmittingAuthRepository()),
      act: (bloc) => bloc.add(const AuthLoginRequested('a@b.com', 'password')),
      expect: () => [const AuthState.authenticated('user_id')],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [authenticated] after AuthGoogleSignInRequested succeeds',
      build: () => AuthBloc(authRepository: LoginEmittingAuthRepository()),
      act: (bloc) => bloc.add(AuthGoogleSignInRequested()),
      expect: () => [const AuthState.authenticated('google_user_id')],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [authenticated] after AuthAppleSignInRequested succeeds',
      build: () => AuthBloc(authRepository: LoginEmittingAuthRepository()),
      act: (bloc) => bloc.add(AuthAppleSignInRequested()),
      expect: () => [const AuthState.authenticated('apple_user_id')],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [failure] when AuthGoogleSignInRequested throws',
      build: () => AuthBloc(authRepository: ThrowingAuthRepository()),
      act: (bloc) => bloc.add(AuthGoogleSignInRequested()),
      expect: () => [
        isA<AuthState>().having(
          (s) => s.status,
          'status',
          AuthStatus.failure,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [failure] when AuthAppleSignInRequested throws',
      build: () => AuthBloc(authRepository: ThrowingAuthRepository()),
      act: (bloc) => bloc.add(AuthAppleSignInRequested()),
      expect: () => [
        isA<AuthState>().having(
          (s) => s.status,
          'status',
          AuthStatus.failure,
        ),
      ],
    );
  });
}
