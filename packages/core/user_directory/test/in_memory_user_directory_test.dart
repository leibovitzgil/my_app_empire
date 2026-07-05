import 'package:core_utils/core_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_directory/user_directory.dart';

void main() {
  group('InMemoryUserDirectory', () {
    test('a seeded, discoverable user resolves by email', () async {
      final directory = InMemoryUserDirectory(
        seed: const [
          DirectoryUser(
            uid: 'uid-1',
            email: 'sam@example.com',
            displayName: 'Sam',
          ),
        ],
      );

      final result = await directory.lookupByEmail('sam@example.com');

      expect(result, isA<Success<DirectoryUser?>>());
      expect(result.valueOrNull?.uid, 'uid-1');
      expect(result.valueOrNull?.displayName, 'Sam');
    });

    test('lookup is case- and whitespace-insensitive on email', () async {
      final directory = InMemoryUserDirectory(
        seed: const [DirectoryUser(uid: 'uid-1', email: 'Sam@Example.com')],
      );

      final result = await directory.lookupByEmail(' sam@example.com ');

      expect(result.valueOrNull?.uid, 'uid-1');
    });

    test('an unknown email resolves to Success(null)', () async {
      final directory = InMemoryUserDirectory();

      final result = await directory.lookupByEmail('nobody@example.com');

      expect(result, isA<Success<DirectoryUser?>>());
      expect(result.valueOrNull, isNull);
    });

    test(
      'a non-discoverable user resolves to Success(null), same as no '
      'account at all',
      () async {
        final directory = InMemoryUserDirectory(
          seed: const [
            DirectoryUser(
              uid: 'uid-1',
              email: 'private@example.com',
              discoverable: false,
            ),
          ],
        );

        final result = await directory.lookupByEmail('private@example.com');

        expect(result, isA<Success<DirectoryUser?>>());
        expect(result.valueOrNull, isNull);
      },
    );

    test('upsertSelf publishes an entry lookupByEmail then resolves', () async {
      final directory = InMemoryUserDirectory();

      final upsertResult = await directory.upsertSelf(
        const DirectoryUser(uid: 'uid-2', email: 'new@example.com'),
      );
      expect(upsertResult, isA<Success<void>>());

      final result = await directory.lookupByEmail('new@example.com');
      expect(result.valueOrNull?.uid, 'uid-2');
    });

    test('upsertSelf replaces a prior entry for the same email', () async {
      final directory = InMemoryUserDirectory(
        seed: const [DirectoryUser(uid: 'uid-1', email: 'sam@example.com')],
      );

      await directory.upsertSelf(
        const DirectoryUser(
          uid: 'uid-1',
          email: 'sam@example.com',
          displayName: 'Sam Smith',
        ),
      );

      final result = await directory.lookupByEmail('sam@example.com');
      expect(result.valueOrNull?.displayName, 'Sam Smith');
    });
  });
}
