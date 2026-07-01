import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_roles/user_roles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalUserRoleRepository', () {
    late LocalStorageService storage;
    late StreamController<String?> userIdController;
    late LocalUserRoleRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      userIdController = StreamController<String?>.broadcast();
      repository = LocalUserRoleRepository(
        storage: storage,
        userIdStream: userIdController.stream,
      );
    });

    tearDown(() {
      repository.dispose();
      unawaited(userIdController.close());
    });

    test('defaults to guest when unassigned', () async {
      userIdController.add('user-1');
      await pumpEventQueue();

      final result = await repository.getRole();

      expect(result, isA<Success<AppRole>>());
      expect(result.valueOrNull, AppRole.guest);
    });

    test('hasPermission honors the default mapping', () async {
      userIdController.add('user-1');
      await pumpEventQueue();
      await repository.assignRole('user-1', AppRole.member);

      expect(
        repository.hasPermission(Permissions.accessPremiumContent),
        isTrue,
      );
      expect(repository.hasPermission(Permissions.viewAdminPanel), isFalse);
    });

    test('unknown permission returns false, never throws', () async {
      expect(repository.hasPermission('totally_unknown'), isFalse);
    });

    test(
      'assignRole persists and a fresh repository resolves it on restart',
      () async {
        userIdController.add('user-1');
        await pumpEventQueue();

        final assignResult = await repository.assignRole(
          'user-1',
          AppRole.admin,
        );
        expect(assignResult, isA<Success<void>>());

        // Simulate a restart: a fresh repository over the same storage.
        final restartUserIdController = StreamController<String?>.broadcast();
        final freshRepository = LocalUserRoleRepository(
          storage: storage,
          userIdStream: restartUserIdController.stream,
        );
        addTearDown(freshRepository.dispose);
        addTearDown(() => unawaited(restartUserIdController.close()));

        restartUserIdController.add('user-1');
        await pumpEventQueue();

        final result = await freshRepository.getRole();
        expect(result.valueOrNull, AppRole.admin);
      },
    );

    test(
      'distinct-until-changed: assigning same role twice emits once',
      () async {
        userIdController.add('user-1');
        await pumpEventQueue();

        final emissions = <AppRole>[];
        final subscription = repository.currentRole.listen(emissions.add);
        addTearDown(subscription.cancel);

        await repository.assignRole('user-1', AppRole.member);
        await repository.assignRole('user-1', AppRole.member);
        await pumpEventQueue();

        expect(emissions, [AppRole.member]);
      },
    );

    test('user stream emitting null resets to guest and emits', () async {
      userIdController.add('user-1');
      await pumpEventQueue();
      await repository.assignRole('user-1', AppRole.admin);
      await pumpEventQueue();
      expect(repository.hasMinimumRole(AppRole.admin), isTrue);

      final emissions = <AppRole>[];
      final subscription = repository.currentRole.listen(emissions.add);
      addTearDown(subscription.cancel);

      userIdController.add(null);
      await pumpEventQueue();

      expect(emissions, [AppRole.guest]);
      expect(repository.hasMinimumRole(AppRole.member), isFalse);
    });

    test('custom rolePermissions override the defaults', () async {
      final customUserIdController = StreamController<String?>.broadcast();
      final customRepository = LocalUserRoleRepository(
        storage: storage,
        userIdStream: customUserIdController.stream,
        rolePermissions: const {
          'member': {'custom_permission'},
        },
      );
      addTearDown(customRepository.dispose);
      addTearDown(() => unawaited(customUserIdController.close()));

      customUserIdController.add('user-1');
      await pumpEventQueue();
      await customRepository.assignRole('user-1', AppRole.member);
      await pumpEventQueue();

      expect(customRepository.hasPermission('custom_permission'), isTrue);
      expect(
        customRepository.hasPermission(Permissions.accessPremiumContent),
        isFalse,
      );
    });

    test('a custom AppRole round-trips via knownRoles', () async {
      const moderator = AppRole(name: 'moderator', rank: 15);
      final customUserIdController = StreamController<String?>.broadcast();
      final customRepository = LocalUserRoleRepository(
        storage: storage,
        userIdStream: customUserIdController.stream,
        knownRoles: [AppRole.guest, AppRole.member, moderator, AppRole.admin],
      );
      addTearDown(customRepository.dispose);
      addTearDown(() => unawaited(customUserIdController.close()));

      customUserIdController.add('user-1');
      await pumpEventQueue();
      await customRepository.assignRole('user-1', moderator);
      await pumpEventQueue();

      final result = await customRepository.getRole();
      expect(result.valueOrNull, moderator);
      expect(customRepository.hasMinimumRole(AppRole.member), isTrue);
      expect(customRepository.hasMinimumRole(AppRole.admin), isFalse);
    });
  });
}
