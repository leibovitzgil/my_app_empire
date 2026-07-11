// Proves the account→directory upsert listener `configureDependencies()`
// wires (now backend-agnostic, M1.5): whenever the signed-in identity
// changes — sign-in or a display-name edit — this device's own
// `usersByEmail`-style entry is re-published to whichever `UserDirectory`
// is bound, so invite-by-email resolves the freshest name. Runs against the
// default in-memory branch; the Firestore variant of the same seam is the
// M1.10 emulator E2E's concern.
import 'package:duet/data/directory_publisher.dart';
import 'package:duet/injection.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_directory/user_directory.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  tearDown(getIt.reset);

  test('a display-name edit re-publishes the directory entry', () async {
    await configureDependencies();
    final auth = getIt<AuthRepository>();
    final directory = getIt<UserDirectory>();

    await auth.login('jane.doe@example.com', 'pw');
    // Let the broadcast account emission reach the upsert listener and the
    // (async, best-effort) upsert land.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final before = await directory.lookupByEmail('jane.doe@example.com');
    expect(before.valueOrNull?.displayName, 'Jane.doe');
    expect(before.valueOrNull?.uid, 'user_id_123');

    await auth.updateDisplayName('Jane D.');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final after = await directory.lookupByEmail('jane.doe@example.com');
    expect(after.valueOrNull?.displayName, 'Jane D.');
  });

  test(
    'a discoverable=false choice survives a fresh sign-in (clobber '
    'regression, M1.6)',
    () async {
      await configureDependencies();
      final auth = getIt<AuthRepository>();
      final directory = getIt<UserDirectory>();

      await auth.login('jane.doe@example.com', 'pw');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Visible by default…
      final before = await directory.lookupByEmail('jane.doe@example.com');
      expect(before.valueOrNull, isNotNull);

      // …until the user opts out.
      await getIt<DirectoryPublisher>().setDiscoverable(false);
      final hidden = await directory.lookupByEmail('jane.doe@example.com');
      expect(hidden.valueOrNull, isNull);

      // A fresh sign-in used to force-write discoverable: true; the choice
      // must survive the re-login upsert.
      await auth.logout();
      await auth.login('jane.doe@example.com', 'pw');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final after = await directory.lookupByEmail('jane.doe@example.com');
      expect(after.valueOrNull, isNull);
    },
  );
}
