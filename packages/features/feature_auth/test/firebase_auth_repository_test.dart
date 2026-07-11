import 'package:core_utils/core_utils.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth {}

class _MockUserCredential extends Mock
    implements firebase_auth.UserCredential {}

class _MockUser extends Mock implements firebase_auth.User {}

class _MockUserInfo extends Mock implements firebase_auth.UserInfo {}

firebase_auth.UserInfo _providerInfo(String providerId) {
  final info = _MockUserInfo();
  when(() => info.providerId).thenReturn(providerId);
  return info;
}

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
      registerFallbackValue(
        firebase_auth.EmailAuthProvider.credential(
          email: 'fallback@x.y',
          password: 'fallback',
        ),
      );
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

    test('updateDisplayName trims, updates, and reloads', () async {
      final user = _MockUser();
      when(
        () => user.updateDisplayName(any<String>()),
      ).thenAnswer((_) async {});
      when(user.reload).thenAnswer((_) async {});
      when(() => firebaseAuth.currentUser).thenReturn(user);

      final result = await repository.updateDisplayName('  Jane D.  ');

      expect(result, isA<Success<void>>());
      verify(() => user.updateDisplayName('Jane D.')).called(1);
      verify(user.reload).called(1);
    });

    test('updateDisplayName rejects a blank name', () async {
      final user = _MockUser();
      when(() => firebaseAuth.currentUser).thenReturn(user);

      final result = await repository.updateDisplayName('   ');

      expect(
        result,
        isA<ResultFailure<void>>().having(
          (f) => f.error,
          'error',
          const AuthFailure.unknown('empty-display-name'),
        ),
      );
      verifyNever(() => user.updateDisplayName(any<String>()));
    });

    test('updateDisplayName fails when signed out', () async {
      when(() => firebaseAuth.currentUser).thenReturn(null);

      final result = await repository.updateDisplayName('Jane');

      expect(
        result,
        isA<ResultFailure<void>>().having(
          (f) => f.error,
          'error',
          const AuthFailure.unknown('no-signed-in-user'),
        ),
      );
    });

    test('updateDisplayName maps requires-recent-login', () async {
      final user = _MockUser();
      when(() => user.updateDisplayName(any<String>())).thenThrow(
        firebase_auth.FirebaseAuthException(code: 'requires-recent-login'),
      );
      when(() => firebaseAuth.currentUser).thenReturn(user);

      final result = await repository.updateDisplayName('Jane');

      expect(
        result,
        isA<ResultFailure<void>>().having(
          (f) => f.error,
          'error',
          const AuthFailure.requiresRecentLogin(),
        ),
      );
    });

    test('reauthenticate with a password confirms the credential', () async {
      final user = _MockUser();
      when(() => user.email).thenReturn('sam@example.com');
      when(
        () => user.reauthenticateWithCredential(
          any<firebase_auth.AuthCredential>(),
        ),
      ).thenAnswer((_) async => _MockUserCredential());
      when(() => firebaseAuth.currentUser).thenReturn(user);

      final result = await repository.reauthenticate(password: 'secret');

      expect(result, isA<Success<void>>());
      verify(
        () => user.reauthenticateWithCredential(
          any<firebase_auth.AuthCredential>(),
        ),
      ).called(1);
    });

    test(
      'reauthenticate maps a wrong password to invalidCredentials',
      () async {
        final user = _MockUser();
        when(() => user.email).thenReturn('sam@example.com');
        when(
          () => user.reauthenticateWithCredential(
            any<firebase_auth.AuthCredential>(),
          ),
        ).thenThrow(
          firebase_auth.FirebaseAuthException(code: 'wrong-password'),
        );
        when(() => firebaseAuth.currentUser).thenReturn(user);

        final result = await repository.reauthenticate(password: 'nope');

        expect(
          result,
          isA<ResultFailure<void>>().having(
            (f) => f.error,
            'error',
            const AuthFailure.invalidCredentials(),
          ),
        );
      },
    );

    test(
      'reauthenticate re-runs the OAuth flow for provider accounts',
      () async {
        final user = _MockUser();
        // Built before the `when` below: constructing this mock inside the
        // thenReturn argument would run its own `when` mid-registration.
        final providers = [_providerInfo('google.com')];
        when(() => user.providerData).thenReturn(providers);
        when(
          () => user.reauthenticateWithProvider(
            any<firebase_auth.AuthProvider>(),
          ),
        ).thenAnswer((_) async => _MockUserCredential());
        when(() => firebaseAuth.currentUser).thenReturn(user);

        final result = await repository.reauthenticate();

        expect(result, isA<Success<void>>());
        verify(
          () => user.reauthenticateWithProvider(
            any<firebase_auth.AuthProvider>(),
          ),
        ).called(1);
      },
    );

    test('a cancelled provider re-auth maps to cancelled', () async {
      final user = _MockUser();
      final providers = [_providerInfo('apple.com')];
      when(() => user.providerData).thenReturn(providers);
      when(
        () => user.reauthenticateWithProvider(
          any<firebase_auth.AuthProvider>(),
        ),
      ).thenThrow(firebase_auth.FirebaseAuthException(code: 'canceled'));
      when(() => firebaseAuth.currentUser).thenReturn(user);

      final result = await repository.reauthenticate();

      expect(
        result,
        isA<ResultFailure<void>>().having(
          (f) => f.error,
          'error',
          const AuthFailure.cancelled(),
        ),
      );
    });

    test(
      'a password account without a password fails with invalidCredentials',
      () async {
        final user = _MockUser();
        final providers = [_providerInfo('password')];
        when(() => user.providerData).thenReturn(providers);
        when(() => firebaseAuth.currentUser).thenReturn(user);

        final result = await repository.reauthenticate();

        expect(
          result,
          isA<ResultFailure<void>>().having(
            (f) => f.error,
            'error',
            const AuthFailure.invalidCredentials(),
          ),
        );
      },
    );

    test('reauthenticate fails when signed out', () async {
      when(() => firebaseAuth.currentUser).thenReturn(null);

      final result = await repository.reauthenticate(password: 'secret');

      expect(
        result,
        isA<ResultFailure<void>>().having(
          (f) => f.error,
          'error',
          const AuthFailure.unknown('no-signed-in-user'),
        ),
      );
    });

    test('sendPasswordReset succeeds with a Success', () async {
      when(
        () => firebaseAuth.sendPasswordResetEmail(
          email: any<String>(named: 'email'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.sendPasswordReset('a@b.com');

      expect(result, isA<Success<void>>());
      verify(
        () => firebaseAuth.sendPasswordResetEmail(email: 'a@b.com'),
      ).called(1);
    });

    test('sendPasswordReset maps an invalid email to the taxonomy', () async {
      when(
        () => firebaseAuth.sendPasswordResetEmail(
          email: any<String>(named: 'email'),
        ),
      ).thenThrow(firebase_auth.FirebaseAuthException(code: 'invalid-email'));

      final result = await repository.sendPasswordReset('not-an-email');

      expect(
        result,
        isA<ResultFailure<void>>().having(
          (f) => f.error,
          'error',
          const AuthFailure.invalidEmail(),
        ),
      );
    });

    test('sendEmailVerification sends via the signed-in user', () async {
      final user = _MockUser();
      when(user.sendEmailVerification).thenAnswer((_) async {});
      when(() => firebaseAuth.currentUser).thenReturn(user);

      final result = await repository.sendEmailVerification();

      expect(result, isA<Success<void>>());
      verify(user.sendEmailVerification).called(1);
    });

    test('sendEmailVerification fails when signed out', () async {
      when(() => firebaseAuth.currentUser).thenReturn(null);

      final result = await repository.sendEmailVerification();

      expect(
        result,
        isA<ResultFailure<void>>().having(
          (f) => f.error,
          'error',
          const AuthFailure.unknown('no-signed-in-user'),
        ),
      );
    });

    test('refreshAccount reloads the signed-in profile', () async {
      final user = _MockUser();
      when(user.reload).thenAnswer((_) async {});
      when(() => firebaseAuth.currentUser).thenReturn(user);

      await repository.refreshAccount();

      verify(user.reload).called(1);
    });

    test('refreshAccount is a no-op when signed out', () async {
      when(() => firebaseAuth.currentUser).thenReturn(null);

      await expectLater(repository.refreshAccount(), completes);
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
