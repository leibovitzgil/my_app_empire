import 'package:flutter/widgets.dart';
import 'package:user_roles/src/domain/app_role.dart';
import 'package:user_roles/src/domain/permission.dart';
import 'package:user_roles/src/domain/user_role_repository.dart';

/// Rebuilds on role changes; shows [child] only if the current role grants
/// [permission], else [fallback] (default: `SizedBox.shrink()`).
class PermissionGate extends StatelessWidget {
  /// Creates a gate that shows [child] when [repository] grants
  /// [permission], otherwise [fallback].
  const PermissionGate({
    required this.repository,
    required this.permission,
    required this.child,
    super.key,
    this.fallback = const SizedBox.shrink(),
  });

  /// The repository whose role/permissions drive this gate.
  final UserRoleRepository repository;

  /// The permission required to show [child].
  final Permission permission;

  /// The widget to show when the permission is granted.
  final Widget child;

  /// The widget to show when the permission is not granted.
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppRole>(
      stream: repository.currentRole,
      builder: (context, snapshot) {
        return repository.hasPermission(permission) ? child : fallback;
      },
    );
  }
}

/// Rebuilds on role changes; shows [child] only if the current role's rank
/// is at least [minimumRole]'s rank, else [fallback] (default:
/// `SizedBox.shrink()`).
class RoleGate extends StatelessWidget {
  /// Creates a gate that shows [child] when [repository]'s current role is
  /// at least [minimumRole], otherwise [fallback].
  const RoleGate({
    required this.repository,
    required this.minimumRole,
    required this.child,
    super.key,
    this.fallback = const SizedBox.shrink(),
  });

  /// The repository whose role drives this gate.
  final UserRoleRepository repository;

  /// The minimum role rank required to show [child].
  final AppRole minimumRole;

  /// The widget to show when the minimum role is met.
  final Widget child;

  /// The widget to show when the minimum role is not met.
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppRole>(
      stream: repository.currentRole,
      builder: (context, snapshot) {
        return repository.hasMinimumRole(minimumRole) ? child : fallback;
      },
    );
  }
}
