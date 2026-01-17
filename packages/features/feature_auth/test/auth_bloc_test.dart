import 'package:bloc_test/bloc_test.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package.flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('AuthBloc', () {
    late AuthRepository authRepository;

    setUp(() {
      authRepository = MockAuthRepository();
    });

    test('initial state is unknown', () {
      expect(
        AuthBloc(authRepository: authRepository).state,
        const AuthState.unknown(),
      );
    });

    blocTest<AuthBloc, AuthState>(
      'emits [unauthenticated] when user stream emits null',
      build: () {
        when(() => authRepository.user).thenAnswer(
          (_) => Stream.value(null),
        );
        return AuthBloc(
          authRepository: authRepository,
        );
      },
      expect: () => [const AuthState.unauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [authenticated] when user stream emits a user',
      build: () {
        when(() => authRepository.user).thenAnswer(
          (_) => Stream.value('user'),
        );
        return AuthBloc(
          authRepository: authRepository,
        );
      },
      expect: () => [const AuthState.authenticated('user')],
    );

    blocTest<AuthBloc, AuthState>(
      'calls logout on AuthLogoutRequested',
      build: () {
        when(() => authRepository.user).thenAnswer(
          (_) => const Stream.empty(),
        );
        when(() => authRepository.logout()).thenAnswer((_) async {});
        return AuthBloc(
          authRepository: authRepository,
        );
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      verify: (_) {
        verify(() => authRepository.logout()).called(1);
      },
    );
  });
}
