import 'package:core_utils/core_utils.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth {}

class _MockUserCredential extends Mock
    implements firebase_auth.UserCredential {}

class _MockUser extends Mock implements firebase_auth.User {}

void main() {
  group('mapFirebaseAuthCode', () {
    const expectations = <String, AuthFailure>{
      'invalid-credential': AuthFailure.invalidCredentials(),
      'wrong-password': AuthFailure.invalidCredentials(),
      'user-not-found': AuthFailure.invalidCredentials(),
      'INVALID_LOGIN_CREDENTIALS': AuthFailure.invalidCredentials(),
      'email-already-in-use': AuthFailure.emailInUse(),
      'weak-password': AuthFailure.weakPassword(),
      'invalid-email': AuthFailure.invalidEmail(),
      'user-disabled': AuthFailure.userDisabled(),
      'requires-recent-login': AuthFailure.requiresRecentLogin(),
      'network-request-failed': AuthFailure.network(),
      'canceled': AuthFailure.cancelled(),
      'cancelled': AuthFailure.cancelled(),
      'user-cancelled': AuthFailure.cancelled(),
      'popup-closed-by-user': AuthFailure.cancelled(),
      'web-context-canceled': AuthFailure.cancelled(),
      'web-context-cancelled': AuthFailure.cancelled(),
    };

    for (final MapEntry(key: code, value: failure) in expectations.entries) {
      test("maps '$code' to ${failure.code.name}", () {
        expect(mapFirebaseAuthCode(code), failure);
      });
    }

    test('maps an unrecognized code to unknown carrying the code', () {
      expect(
        mapFirebaseAuthCode('some-new-code'),
        const AuthFailure.unknown('some-new-code'),
      );
    });
  });

  group('FirebaseAuthRepository', () {
    late _MockFirebaseAuth firebaseAuth;
    late FirebaseAuthRepository repository;

    setUpAll(() {
      registerFallbackValue(firebase_auth.GoogleAuthProvider());
    });

    setUp(() {
      firebaseAuth = _MockFirebaseAuth();
      repository = FirebaseAuthRepository(firebaseAuth: firebaseAuth);
    });

    test('login succeeds with a Success', () async {
      when(
        () => firebaseAuth.signInWithEmailAndPassword(
          email: any<String>(named: 'email'),
          password: any<String>(named: 'password'),
        ),
      ).thenAnswer((_) async => _MockUserCredential());

      final result = await repository.login('a@b.com', 'password');

      expect(result, isA<Success<void>>());
    });

    test('login maps a FirebaseAuthException to the taxonomy', () async {
      when(
        () => firebaseAuth.signInWithEmailAndPassword(
          email: any<String>(named: 'email'),
          password: any<String>(named: 'password'),
        ),
      ).thenThrow(firebase_auth.FirebaseAuthException(code: 'wrong-password'));

      final result = await repository.login('a@b.com', 'nope');

      expect(
        result,
        isA<ResultFailure<void>>().having(
          (f) => f.error,
          'error',
          const AuthFailure.invalidCredentials(),
        ),
      );
    });

    test('login wraps a non-Firebase error as unknown', () async {
      final boom = Exception('boom');
      when(
        () => firebaseAuth.signInWithEmailAndPassword(
          email: any<String>(named: 'email'),
          password: any<String>(named: 'password'),
        ),
      ).thenThrow(boom);

      final result = await repository.login('a@b.com', 'password');

      expect(
        result,
        isA<ResultFailure<void>>().having(
          (f) => f.error,
          'error',
          AuthFailure.unknown(boom),
        ),
      );
    });

    test('signUp sets the display name on the fresh profile', () async {
      final user = _MockUser();
      final credential = _MockUserCredential();
      when(() => credential.user).thenReturn(user);
      when(
        () => user.updateDisplayName(any<String>()),
      ).thenAnswer((_) async {});
      when(user.reload).thenAnswer((_) async {});
      when(
        () => firebaseAuth.createUserWithEmailAndPassword(
          email: any<String>(named: 'email'),
          password: any<String>(named: 'password'),
        ),
      ).thenAnswer((_) async => credential);

      final result = await repository.signUp(
        'new@b.com',
        'pw',
        displayName: '  Jane Doe  ',
      );

      expect(result, isA<Success<void>>());
      verify(() => user.updateDisplayName('Jane Doe')).called(1);
      verify(user.reload).called(1);
    });

    test('signUp without a display name skips the profile update', () async {
      final user = _MockUser();
      final credential = _MockUserCredential();
      when(() => credential.user).thenReturn(user);
      when(
        () => firebaseAuth.createUserWithEmailAndPassword(
          email: any<String>(named: 'email'),
          password: any<String>(named: 'password'),
        ),
      ).thenAnswer((_) async => credential);

      final result = await repository.signUp('new@b.com', 'pw');

      expect(result, isA<Success<void>>());
      verifyNever(() => user.updateDisplayName(any<String>()));
    });

    test('signUp maps a duplicate email to emailInUse', () async {
      when(
        () => firebaseAuth.createUserWithEmailAndPassword(
          email: any<String>(named: 'email'),
          password: any<String>(named: 'password'),
        ),
      ).thenThrow(
        firebase_auth.FirebaseAuthException(code: 'email-already-in-use'),
      );

      final result = await repository.signUp('dup@b.com', 'pw');

      expect(
        result,
        isA<ResultFailure<void>>().having(
          (f) => f.error,
          'error',
          const AuthFailure.emailInUse(),
        ),
      );
    });

    test('a cancelled provider flow maps to cancelled', () async {
      when(
        () => firebaseAuth.signInWithProvider(
          any<firebase_auth.AuthProvider>(),
        ),
      ).thenThrow(firebase_auth.FirebaseAuthException(code: 'canceled'));

      final result = await repository.signInWithGoogle();

      expect(
        result,
        isA<ResultFailure<void>>().having(
          (f) => f.error,
          'error',
          const AuthFailure.cancelled(),
        ),
      );
    });

    test('a provider flow succeeds with a Success', () async {
      when(
        () => firebaseAuth.signInWithProvider(
          any<firebase_auth.AuthProvider>(),
        ),
      ).thenAnswer((_) async => _MockUserCredential());

      final result = await repository.signInWithApple();

      expect(result, isA<Success<void>>());
    });

    test('logout maps a network failure to the taxonomy', () async {
      when(firebaseAuth.signOut).thenThrow(
        firebase_auth.FirebaseAuthException(code: 'network-request-failed'),
      );

      final result = await repository.logout();

      expect(
        result,
        isA<ResultFailure<void>>().having(
          (f) => f.error,
          'error',
          const AuthFailure.network(),
        ),
      );
    });

    test('logout succeeds with a Success', () async {
      when(firebaseAuth.signOut).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result, isA<Success<void>>());
    });
  });
}
