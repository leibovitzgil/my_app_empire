import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_roles/user_roles.dart';

class _FakeUserRoleRepository implements UserRoleRepository {
  _FakeUserRoleRepository({AppRole initialRole = AppRole.guest})
    : _role = initialRole;

  final StreamController<AppRole> _controller =
      StreamController<AppRole>.broadcast();

  AppRole _role;

  void setRole(AppRole role) {
    _role = role;
    _controller.add(role);
  }

  void dispose() => unawaited(_controller.close());

  @override
  Stream<AppRole> get currentRole => _controller.stream;

  @override
  Future<Result<AppRole>> getRole() async => Success<AppRole>(_role);

  @override
  bool hasPermission(Permission permission) =>
      (defaultRolePermissions[_role.name] ?? const {}).contains(permission);

  @override
  bool hasMinimumRole(AppRole role) => _role >= role;

  @override
  Future<Result<void>> assignRole(String userId, AppRole role) async {
    setRole(role);
    return const Success<void>(null);
  }
}

void main() {
  group('PermissionGate', () {
    testWidgets('shows child when the permission is granted', (
      tester,
    ) async {
      final repository = _FakeUserRoleRepository(initialRole: AppRole.admin);
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: PermissionGate(
            repository: repository,
            permission: Permissions.viewAdminPanel,
            fallback: const Text('no access'),
            child: const Text('admin panel'),
          ),
        ),
      );

      expect(find.text('admin panel'), findsOneWidget);
      expect(find.text('no access'), findsNothing);
    });

    testWidgets('shows fallback when the permission is not granted', (
      tester,
    ) async {
      final repository = _FakeUserRoleRepository();
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: PermissionGate(
            repository: repository,
            permission: Permissions.viewAdminPanel,
            fallback: const Text('no access'),
            child: const Text('admin panel'),
          ),
        ),
      );

      expect(find.text('admin panel'), findsNothing);
      expect(find.text('no access'), findsOneWidget);
    });

    testWidgets('rebuilds when the role stream emits a change', (
      tester,
    ) async {
      final repository = _FakeUserRoleRepository();
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: PermissionGate(
            repository: repository,
            permission: Permissions.viewAdminPanel,
            fallback: const Text('no access'),
            child: const Text('admin panel'),
          ),
        ),
      );

      expect(find.text('no access'), findsOneWidget);

      repository.setRole(AppRole.admin);
      await tester.pump();
      await tester.pump();

      expect(find.text('admin panel'), findsOneWidget);
      expect(find.text('no access'), findsNothing);
    });
  });

  group('RoleGate', () {
    testWidgets('shows child when the minimum role is met', (tester) async {
      final repository = _FakeUserRoleRepository(initialRole: AppRole.admin);
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RoleGate(
            repository: repository,
            minimumRole: AppRole.member,
            fallback: const Text('locked'),
            child: const Text('gated content'),
          ),
        ),
      );

      expect(find.text('gated content'), findsOneWidget);
      expect(find.text('locked'), findsNothing);
    });

    testWidgets('shows fallback when the minimum role is not met', (
      tester,
    ) async {
      final repository = _FakeUserRoleRepository();
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RoleGate(
            repository: repository,
            minimumRole: AppRole.member,
            fallback: const Text('locked'),
            child: const Text('gated content'),
          ),
        ),
      );

      expect(find.text('gated content'), findsNothing);
      expect(find.text('locked'), findsOneWidget);
    });

    testWidgets('rebuilds when the role stream emits a change', (
      tester,
    ) async {
      final repository = _FakeUserRoleRepository();
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RoleGate(
            repository: repository,
            minimumRole: AppRole.member,
            fallback: const Text('locked'),
            child: const Text('gated content'),
          ),
        ),
      );

      expect(find.text('locked'), findsOneWidget);

      repository.setRole(AppRole.member);
      await tester.pump();
      await tester.pump();

      expect(find.text('gated content'), findsOneWidget);
      expect(find.text('locked'), findsNothing);
    });
  });
}
