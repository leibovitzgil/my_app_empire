import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Emits a user id on [login] and null on [logout], like a real backend.
class LoginEmittingAuthRepository implements AuthRepository {
  final _controller = StreamController<String?>.broadcast();

  @override
  Stream<String?> get user => _controller.stream;

  @override
  Future<Result<void>> login(String email, String password) async {
    _controller.add('user_id');
    return const Success(null);
  }

  @override
  Future<Result<void>> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    _controller.add('new_user_id');
    return const Success(null);
  }

  @override
  Future<Result<void>> signInWithGoogle() async {
    _controller.add('google_user_id');
    return const Success(null);
  }

  @override
  Future<Result<void>> signInWithApple() async {
    _controller.add('apple_user_id');
    return const Success(null);
  }

  @override
  Future<Result<void>> logout() async {
    _controller.add(null);
    return const Success(null);
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({Stream<String?>? userStream})
    : _userStream = userStream ?? const Stream.empty();
  final Stream<String?> _userStream;

  @override
  Stream<String?> get user => _userStream;

  @override
  Future<Result<void>> login(String email, String password) async =>
      const Success(null);

  @override
  Future<Result<void>> signUp(
    String email,
    String password, {
    String? displayName,
  }) async => const Success(null);

  @override
  Future<Result<void>> signInWithGoogle() async => const Success(null);

  @override
  Future<Result<void>> signInWithApple() async => const Success(null);

  @override
  Future<Result<void>> logout() async => const Success(null);
}

/// Fails every flow with [failure], so we can assert the bloc folds
/// repository failures into [AuthState.failure] (never a thrown error).
class FailingAuthRepository implements AuthRepository {
  FailingAuthRepository([this.failure = const AuthFailure.unknown()]);

  final AuthFailure failure;

  @override
  Stream<String?> get user => const Stream.empty();

  @override
  Future<Result<void>> login(String email, String password) async =>
      ResultFailure(failure);

  @override
  Future<Result<void>> signUp(
    String email,
    String password, {
    String? displayName,
  }) async => ResultFailure(failure);

  @override
  Future<Result<void>> signInWithGoogle() async => ResultFailure(failure);

  @override
  Future<Result<void>> signInWithApple() async => ResultFailure(failure);

  @override
  Future<Result<void>> logout() async => ResultFailure(failure);
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
      'emits [authenticated] after AuthSignUpRequested succeeds',
      build: () => AuthBloc(authRepository: LoginEmittingAuthRepository()),
      act: (bloc) => bloc.add(
        const AuthSignUpRequested('new@b.com', 'pw', displayName: 'New'),
      ),
      expect: () => [const AuthState.authenticated('new_user_id')],
    );

    blocTest<AuthBloc, AuthState>(
      'folds a duplicate-email sign-up into [failure] with emailInUse',
      build: () => AuthBloc(
        authRepository: FailingAuthRepository(const AuthFailure.emailInUse()),
      ),
      act: (bloc) => bloc.add(const AuthSignUpRequested('a@b.com', 'pw')),
      expect: () => [const AuthState.failure(AuthFailure.emailInUse())],
    );

    blocTest<AuthBloc, AuthState>(
      'folds a login failure into [failure] carrying the typed AuthFailure',
      build: () => AuthBloc(
        authRepository: FailingAuthRepository(
          const AuthFailure.invalidCredentials(),
        ),
      ),
      act: (bloc) => bloc.add(const AuthLoginRequested('a@b.com', 'nope')),
      expect: () => [
        const AuthState.failure(AuthFailure.invalidCredentials()),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'folds a Google sign-in failure into [failure]',
      build: () => AuthBloc(
        authRepository: FailingAuthRepository(const AuthFailure.cancelled()),
      ),
      act: (bloc) => bloc.add(AuthGoogleSignInRequested()),
      expect: () => [const AuthState.failure(AuthFailure.cancelled())],
    );

    blocTest<AuthBloc, AuthState>(
      'folds an Apple sign-in failure into [failure]',
      build: () => AuthBloc(
        authRepository: FailingAuthRepository(const AuthFailure.network()),
      ),
      act: (bloc) => bloc.add(AuthAppleSignInRequested()),
      expect: () => [const AuthState.failure(AuthFailure.network())],
    );

    blocTest<AuthBloc, AuthState>(
      'a logout failure emits nothing (sign-out is fire-and-forget until '
      'Settings surfaces it, M1.5)',
      build: () => AuthBloc(
        authRepository: FailingAuthRepository(const AuthFailure.network()),
      ),
      act: (bloc) => bloc.add(AuthLogoutRequested()),
      expect: () => <AuthState>[],
    );
  });
}
