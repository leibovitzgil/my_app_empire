import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/duet_roles.dart';
import 'package:duet/ui/role_selection/role_selection_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_roles/user_roles.dart';

/// A hand-written fake, mirroring `feature_auth`'s convention of faking the
/// repository rather than mocking the cubit under test.
class _FakeUserRoleRepository implements UserRoleRepository {
  String? assignedUserId;
  AppRole? assignedRole;
  Object? failure;

  @override
  Stream<AppRole> get currentRole => const Stream.empty();

  @override
  Future<Result<AppRole>> getRole() async => const Success(AppRole.guest);

  @override
  bool hasPermission(Permission permission) => false;

  @override
  bool hasMinimumRole(AppRole role) => false;

  @override
  Future<Result<void>> assignRole(String userId, AppRole role) async {
    if (failure case final error?) return ResultFailure<void>(error);
    assignedUserId = userId;
    assignedRole = role;
    return const Success(null);
  }
}

void main() {
  late _FakeUserRoleRepository repository;
  late RoleSelectionCubit cubit;

  setUp(() {
    repository = _FakeUserRoleRepository();
    cubit = RoleSelectionCubit(
      userRoleRepository: repository,
      currentUserId: () => 'user_1',
    );
  });

  tearDown(() => cubit.close());

  test('initial state has no selection', () {
    expect(cubit.state.selected, isNull);
    expect(cubit.state.status, RoleSelectionStatus.idle);
  });

  test('select highlights a role without persisting it', () {
    cubit.select(DuetRoles.teacher);

    expect(cubit.state.selected, DuetRoles.teacher);
    expect(repository.assignedRole, isNull);
  });

  test('confirm without a selection is a no-op', () async {
    await cubit.confirm();

    expect(cubit.state.status, RoleSelectionStatus.idle);
    expect(repository.assignedRole, isNull);
  });

  test('confirm persists the selected role for the current user', () async {
    cubit.select(DuetRoles.student);

    await cubit.confirm();

    expect(repository.assignedUserId, 'user_1');
    expect(repository.assignedRole, DuetRoles.student);
    expect(cubit.state.status, RoleSelectionStatus.saved);
  });

  test('confirm surfaces a failure from the repository', () async {
    repository.failure = StateError('boom');
    cubit.select(DuetRoles.teacher);

    await cubit.confirm();

    expect(cubit.state.status, RoleSelectionStatus.error);
    expect(cubit.state.error, contains('boom'));
  });
}
