import 'package:core_utils/core_utils.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_directory/user_directory.dart';

void main() {
  group('FirestoreUserDirectory', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreUserDirectory directory;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      directory = FirestoreUserDirectory(firestore: firestore);
    });

    test(
      'upsertSelf then lookupByEmail round-trips a discoverable user',
      () async {
        final upsertResult = await directory.upsertSelf(
          const DirectoryUser(
            uid: 'uid-1',
            email: 'sam@example.com',
            displayName: 'Sam',
          ),
        );
        expect(upsertResult, isA<Success<void>>());

        final result = await directory.lookupByEmail('sam@example.com');

        expect(result, isA<Success<DirectoryUser?>>());
        expect(
          result.valueOrNull,
          const DirectoryUser(
            uid: 'uid-1',
            email: 'sam@example.com',
            displayName: 'Sam',
          ),
        );
      },
    );

    test('lookupByEmail is case- and whitespace-insensitive', () async {
      await directory.upsertSelf(
        const DirectoryUser(uid: 'uid-1', email: 'Sam@Example.com'),
      );

      final result = await directory.lookupByEmail(' sam@example.com ');

      expect(result.valueOrNull?.uid, 'uid-1');
    });

    test('an unknown email resolves to Success(null)', () async {
      final result = await directory.lookupByEmail('nobody@example.com');

      expect(result, isA<Success<DirectoryUser?>>());
      expect(result.valueOrNull, isNull);
    });

    test(
      'a document with discoverable:false resolves to Success(null)',
      () async {
        await firestore
            .collection('usersByEmail')
            .doc('private@example.com')
            .set({
              'uid': 'uid-2',
              'email': 'private@example.com',
              'discoverable': false,
            });

        final result = await directory.lookupByEmail('private@example.com');

        expect(result, isA<Success<DirectoryUser?>>());
        expect(result.valueOrNull, isNull);
      },
    );

    test(
      'a legacy document with no discoverable field is treated as '
      'non-discoverable, not thrown on',
      () async {
        await firestore
            .collection('usersByEmail')
            .doc('legacy@example.com')
            .set({
              'uid': 'uid-3',
              'email': 'legacy@example.com',
            });

        final result = await directory.lookupByEmail('legacy@example.com');

        expect(result, isA<Success<DirectoryUser?>>());
        expect(result.valueOrNull, isNull);
      },
    );

    test('upsertSelf overwrites a prior entry for the same email', () async {
      await directory.upsertSelf(
        const DirectoryUser(uid: 'uid-1', email: 'sam@example.com'),
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
