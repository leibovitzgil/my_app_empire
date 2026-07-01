import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:local_storage/local_storage.dart';
import 'package:user_roles/src/domain/app_role.dart';
import 'package:user_roles/src/domain/permission.dart';
import 'package:user_roles/src/domain/user_role_repository.dart';

/// A [UserRoleRepository] backed by [LocalStorageService] (shared prefs),
/// keyed by a user id stream so the cached role tracks the signed-in user.
class LocalUserRoleRepository implements UserRoleRepository {
  /// Creates a repository persisting via [storage], tracking the current
  /// user via [userIdStream]. [rolePermissions] defaults to
  /// [defaultRolePermissions]; [knownRoles] defaults to [AppRole.defaults]
  /// and is used to resolve a persisted role name back to an [AppRole].
  LocalUserRoleRepository({
    required LocalStorageService storage,
    required Stream<String?> userIdStream,
    Map<String, Set<Permission>>? rolePermissions,
    List<AppRole> knownRoles = AppRole.defaults,
  }) : _storage = storage,
       _rolePermissions = rolePermissions ?? defaultRolePermissions,
       _knownRoles = knownRoles,
       _cachedRole = AppRole.guest {
    _subscription = userIdStream.listen(_onUserIdChanged);
  }

  static const String _keyPrefix = 'user_roles.role.';

  final LocalStorageService _storage;
  final Map<String, Set<Permission>> _rolePermissions;
  final List<AppRole> _knownRoles;
  final StreamController<AppRole> _controller =
      StreamController<AppRole>.broadcast();

  late final StreamSubscription<String?> _subscription;

  AppRole _cachedRole;
  String? _currentUserId;

  /// Releases the subscription to the user id stream.
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_controller.close());
  }

  void _onUserIdChanged(String? userId) {
    _currentUserId = userId;
    if (userId == null) {
      _emitIfChanged(AppRole.guest);
      return;
    }
    final storedName = _storage.getString('$_keyPrefix$userId');
    _emitIfChanged(_resolveRole(storedName));
  }

  AppRole _resolveRole(String? name) {
    if (name == null) {
      return AppRole.guest;
    }
    for (final role in _knownRoles) {
      if (role.name == name) {
        return role;
      }
    }
    return AppRole.guest;
  }

  void _emitIfChanged(AppRole role) {
    if (role == _cachedRole) {
      return;
    }
    _cachedRole = role;
    _controller.add(role);
  }

  @override
  Stream<AppRole> get currentRole => _controller.stream;

  @override
  Future<Result<AppRole>> getRole() => Result.guard(() async => _cachedRole);

  @override
  bool hasPermission(Permission permission) =>
      (_rolePermissions[_cachedRole.name] ?? const {}).contains(permission);

  @override
  bool hasMinimumRole(AppRole role) => _cachedRole >= role;

  @override
  Future<Result<void>> assignRole(String userId, AppRole role) =>
      Result.guard(() async {
        await _storage.setString('$_keyPrefix$userId', role.name);
        if (userId == _currentUserId) {
          _emitIfChanged(role);
        }
      });
}
