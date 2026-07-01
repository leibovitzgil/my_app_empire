import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_roles/user_roles.dart';

void main() {
  group('FirestoreUserRoleRepository', () {
    late FakeFirebaseFirestore firestore;
    late StreamController<String?> userIdController;
    late FirestoreUserRoleRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      userIdController = StreamController<String?>.broadcast();
      repository = FirestoreUserRoleRepository(
        firestore: firestore,
        userIdStream: userIdController.stream,
      );
    });

    tearDown(() {
      repository.dispose();
      unawaited(userIdController.close());
    });

    test('defaults to guest when no doc exists for the user', () async {
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
      await pumpEventQueue();

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
        await pumpEventQueue();

        // Simulate a restart/another device: a fresh repository over the
        // same (fake) Firestore backend.
        final restartUserIdController = StreamController<String?>.broadcast();
        final freshRepository = FirestoreUserRoleRepository(
          firestore: firestore,
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
        await pumpEventQueue();
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
      final customRepository = FirestoreUserRoleRepository(
        firestore: firestore,
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
      final customRepository = FirestoreUserRoleRepository(
        firestore: firestore,
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

    test(
      'external writes (another client/admin/backend) propagate to '
      'currentRole in real time',
      () async {
        userIdController.add('user-1');
        await pumpEventQueue();
        expect(repository.hasMinimumRole(AppRole.member), isFalse);

        final emissions = <AppRole>[];
        final subscription = repository.currentRole.listen(emissions.add);
        addTearDown(subscription.cancel);

        // Simulate an external write that bypasses this repository's
        // assignRole entirely (e.g. an admin console or backend job).
        await firestore.collection('userRoles').doc('user-1').set({
          'role': 'admin',
        });
        await pumpEventQueue();

        expect(emissions, [AppRole.admin]);
        expect(repository.hasPermission(Permissions.viewAdminPanel), isTrue);
        expect(repository.hasMinimumRole(AppRole.admin), isTrue);
      },
    );
  });
}
