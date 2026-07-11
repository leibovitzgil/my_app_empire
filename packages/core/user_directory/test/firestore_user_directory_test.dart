import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_utils/core_utils.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
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
      'a re-upsert carrying discoverable:false keeps the document hidden '
      '(M1.6 clobber regression, Firestore variant)',
      () async {
        // A sign-in style upsert that threads the stored false choice —
        // upsertSelf is a full set, so whatever the caller composes wins;
        // the historical bug was the caller not passing the flag at all.
        await directory.upsertSelf(
          const DirectoryUser(
            uid: 'uid-1',
            email: 'sam@example.com',
            discoverable: false,
          ),
        );
        await directory.upsertSelf(
          const DirectoryUser(
            uid: 'uid-1',
            email: 'sam@example.com',
            displayName: 'Sam',
            discoverable: false,
          ),
        );

        final lookup = await directory.lookupByEmail('sam@example.com');
        expect(lookup.valueOrNull, isNull);

        final raw = await firestore
            .collection('usersByEmail')
            .doc('sam@example.com')
            .get();
        expect(raw.data()?['discoverable'], isFalse);
        expect(raw.data()?['displayName'], 'Sam');
      },
    );

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

    // `fake_cloud_firestore` evaluates no security rules, so the two paths
    // below — where the emulator's rules make a GET *throw* rather than
    // return data — are driven by intercepting the GET on the target doc
    // (the fake's own `whenCalling(...).on(...)` API) and throwing.
    group('when a GET throws (rules deny a stranger reading a hidden '
        'entry)', () {
      DocumentReference<Map<String, dynamic>> docFor(String email) =>
          firestore.collection('usersByEmail').doc(email);

      test(
        'a permission-denied GET resolves to Success(null) — hidden is '
        'indistinguishable from absent (M1.10 regression)',
        () async {
          whenCalling(Invocation.method(#get, null))
              .on(docFor('hidden@example.com'))
              .thenThrow(
                FirebaseException(
                  plugin: 'cloud_firestore',
                  code: 'permission-denied',
                ),
              );

          final result = await directory.lookupByEmail('hidden@example.com');

          expect(result, isA<Success<DirectoryUser?>>());
          expect(result.valueOrNull, isNull);
        },
      );

      test('any other FirebaseException still surfaces as a failure', () async {
        whenCalling(Invocation.method(#get, null))
            .on(docFor('sam@example.com'))
            .thenThrow(
              FirebaseException(
                plugin: 'cloud_firestore',
                code: 'unavailable',
              ),
            );

        final result = await directory.lookupByEmail('sam@example.com');

        expect(result, isA<ResultFailure<DirectoryUser?>>());
      });
    });
  });
}
