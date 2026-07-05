import 'package:feature_auth/feature_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth {}

class _MockUser extends Mock implements firebase_auth.User {}

void main() {
  group('FirebaseAuthRepository as AuthAccountProvider', () {
    late _MockFirebaseAuth firebaseAuth;
    late FirebaseAuthRepository repository;

    setUp(() {
      firebaseAuth = _MockFirebaseAuth();
      repository = FirebaseAuthRepository(firebaseAuth: firebaseAuth);
    });

    test('a signed-in user maps to an AuthAccount (AC-12)', () async {
      final user = _MockUser();
      when(() => user.uid).thenReturn('uid-1');
      when(() => user.email).thenReturn('sam@example.com');
      when(() => user.displayName).thenReturn('Sam');
      when(
        () => firebaseAuth.authStateChanges(),
      ).thenAnswer((_) => Stream.value(user));

      final account = await repository.account.first;

      expect(
        account,
        const AuthAccount(
          uid: 'uid-1',
          email: 'sam@example.com',
          displayName: 'Sam',
        ),
      );
    });

    test('signed-out (null user) maps to a null AuthAccount', () async {
      when(
        () => firebaseAuth.authStateChanges(),
      ).thenAnswer((_) => Stream.value(null));

      final account = await repository.account.first;

      expect(account, isNull);
    });

    test('AuthRepository.user still emits the bare uid, unaffected', () async {
      final user = _MockUser();
      when(() => user.uid).thenReturn('uid-1');
      when(
        () => firebaseAuth.authStateChanges(),
      ).thenAnswer((_) => Stream.value(user));

      final uid = await repository.user.first;

      expect(uid, 'uid-1');
    });

    test('a user with no email maps to a null AuthAccount.email', () async {
      final user = _MockUser();
      when(() => user.uid).thenReturn('uid-2');
      when(() => user.email).thenReturn(null);
      when(() => user.displayName).thenReturn(null);
      when(
        () => firebaseAuth.authStateChanges(),
      ).thenAnswer((_) => Stream.value(user));

      final account = await repository.account.first;

      expect(account?.email, isNull);
      expect(account?.displayName, isNull);
      expect(account?.uid, 'uid-2');
    });
  });
}
