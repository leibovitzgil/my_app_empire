import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:duet/data/directory_publisher.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_directory/user_directory.dart';

/// Records every upsert so tests can assert exactly what was published —
/// `lookupByEmail` can't distinguish "hidden" from "absent" by design.
class _RecordingDirectory implements UserDirectory {
  final List<DirectoryUser> upserts = <DirectoryUser>[];

  @override
  Future<Result<void>> upsertSelf(DirectoryUser user) async {
    upserts.add(user);
    return const Success(null);
  }

  @override
  Future<Result<DirectoryUser?>> lookupByEmail(String email) async =>
      const Success(null);
}

const _account = AuthAccount(
  uid: 'u1',
  email: 'jane@duet.dev',
  displayName: 'Jane',
);

void main() {
  late _RecordingDirectory directory;
  late LocalStorageService storage;
  late StreamController<AuthAccount?> accounts;
  late DirectoryPublisher publisher;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    directory = _RecordingDirectory();
    storage = await LocalStorageService.init();
    accounts = StreamController<AuthAccount?>.broadcast();
    publisher = DirectoryPublisher(
      directory: directory,
      storage: storage,
      accounts: accounts.stream,
    );
  });

  tearDown(() async {
    await publisher.dispose();
    await accounts.close();
  });

  Future<void> emit(AuthAccount? account) async {
    accounts.add(account);
    // Let the listener's async publish land.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('publishes discoverable: true when the user never chose', () async {
    await emit(_account);

    expect(directory.upserts, hasLength(1));
    expect(directory.upserts.single.discoverable, isTrue);
    expect(directory.upserts.single.displayName, 'Jane');
  });

  test(
    'setDiscoverable(false) persists and re-publishes immediately',
    () async {
      await emit(_account);

      final result = await publisher.setDiscoverable(false);

      expect(result, isA<Success<void>>());
      expect(publisher.discoverable, isFalse);
      expect(storage.getBool('settings.discoverable'), isFalse);
      expect(directory.upserts.last.discoverable, isFalse);
    },
  );

  test('a false choice survives a fresh sign-in upsert (clobber '
      'regression)', () async {
    await emit(_account);
    await publisher.setDiscoverable(false);

    // Sign out, sign back in: the fresh emission used to force-write
    // discoverable: true because the listener never passed the flag.
    await emit(null);
    await emit(_account);

    expect(directory.upserts.last.discoverable, isFalse);
  });

  test('a display-name re-publish keeps the stored choice', () async {
    await emit(_account);
    await publisher.setDiscoverable(false);

    await emit(
      const AuthAccount(uid: 'u1', email: 'jane@duet.dev', displayName: 'J.'),
    );

    expect(directory.upserts.last.displayName, 'J.');
    expect(directory.upserts.last.discoverable, isFalse);
  });

  test('publish is a no-op Success while signed out', () async {
    final result = await publisher.publish();

    expect(result, isA<Success<void>>());
    expect(directory.upserts, isEmpty);
  });
}
