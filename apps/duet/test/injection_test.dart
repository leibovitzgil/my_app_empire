// Proves `configureDependencies()`'s DEFAULT (`useFirebase: false`) branch —
// what the standard headless test gate always exercises — binds every
// backend seam this feature added to an in-memory fake, with a real email
// resolvable off `AuthAccountProvider` once signed in, and never constructs
// a Firebase object (there's no `Firebase.initializeApp()` anywhere in this
// file; any accidental real-Firebase call site would throw for lack of an
// initialized app, which this test would then fail on).
import 'package:duet/data/account_purge.dart';
import 'package:duet/data/current_user_email.dart';
import 'package:duet/data/current_user_name.dart';
import 'package:duet/data/mock_auth_repository.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:duet/injection.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_directory/user_directory.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  tearDown(getIt.reset);

  group('configureDependencies (default, useFirebase: false)', () {
    test(
      'binds MockAuthRepository as both AuthRepository and '
      'AuthAccountProvider (the same instance)',
      () async {
        await configureDependencies();

        final authRepository = getIt<AuthRepository>();
        final accountProvider = getIt<AuthAccountProvider>();
        expect(authRepository, isA<MockAuthRepository>());
        expect(accountProvider, isA<MockAuthRepository>());
        expect(identical(authRepository, accountProvider), isTrue);
      },
    );

    test(
      'signing in resolves a real email via CurrentUserEmail/CurrentUserName',
      () async {
        await configureDependencies();

        await getIt<AuthRepository>().login('jane.doe@example.com', 'pw');
        // Let the broadcast stream's event propagate to CurrentUserEmail/
        // CurrentUserName's eager subscriptions.
        await Future<void>.delayed(Duration.zero);

        expect(getIt<CurrentUserEmail>().call(), 'jane.doe@example.com');
        expect(getIt<CurrentUserName>().call(), 'Jane.doe');
      },
    );

    test(
      'binds an in-memory UserDirectory and a shared in-memory '
      'DeviceTokenRegistry/UserMessageGateway instance — never Firebase',
      () async {
        await configureDependencies();

        expect(getIt<UserDirectory>(), isA<InMemoryUserDirectory>());
        final registry = getIt<DeviceTokenRegistry>();
        final gateway = getIt<UserMessageGateway>();
        expect(registry, isA<InMemoryUserMessaging>());
        expect(gateway, isA<InMemoryUserMessaging>());
        expect(identical(registry, gateway), isTrue);
      },
    );

    test(
      'binds DeviceTokenSync with a fake token source that never resolves '
      'a token (FIX-3: never touches NotificationsManager headlessly)',
      () async {
        await configureDependencies();

        // registerCurrent() must complete cleanly without ever resolving
        // NotificationsManager (which would need a platform channel/
        // SharedPreferences in ways this test never sets up for it).
        final result = await getIt<DeviceTokenSync>().registerCurrent();
        expect(result.isSuccess, isTrue);
      },
    );

    test('binds CollaboratorInviteService', () async {
      await configureDependencies();

      expect(
        getIt<CollaboratorInviteService>(),
        isA<DefaultCollaboratorInviteService>(),
      );
    });

    test(
      'binds a MockAccountPurge — never the callable (no Firebase)',
      () async {
        await configureDependencies();

        expect(getIt<AccountPurge>(), isA<MockAccountPurge>());
      },
    );
  });
}
