import 'package:core_utils/core_utils.dart';
import 'package:user_roles/src/domain/app_role.dart';
import 'package:user_roles/src/domain/permission.dart';

/// Contract for reading and assigning app-wide user roles.
abstract class UserRoleRepository {
  /// Emits the current role. Emits [AppRole.guest] when signed out or
  /// unassigned; never null. Distinct-until-changed.
  Stream<AppRole> get currentRole;

  /// One-shot fetch of the current role.
  Future<Result<AppRole>> getRole();

  /// Synchronous check against the latest cached role's permission set.
  /// Unknown permission -> false (never throws).
  bool hasPermission(Permission permission);

  /// True if the cached role's rank is >= [role]'s rank.
  bool hasMinimumRole(AppRole role);

  /// Persists [role] for [userId] and emits it on [currentRole].
  Future<Result<void>> assignRole(String userId, AppRole role);
}
