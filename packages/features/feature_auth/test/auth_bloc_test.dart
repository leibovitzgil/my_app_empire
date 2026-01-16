import 'package:bloc_test/bloc_test.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  final Stream<String?> _userStream;

  FakeAuthRepository({Stream<String?>? userStream})
      : _userStream = userStream ?? const Stream.empty();

  @override
  Stream<String?> get user => _userStream;

  @override
  Future<void> login(String email, String password) async {}

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
  });
}
