import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_utils/core_utils.dart';
import 'package:user_roles/src/domain/app_role.dart';
import 'package:user_roles/src/domain/permission.dart';
import 'package:user_roles/src/domain/user_role_repository.dart';

/// A [UserRoleRepository] backed by Cloud Firestore, keyed by a user id
/// stream so the cached role tracks the signed-in user.
///
/// Schema: a top-level `userRoles` collection with one document per user at
/// `userRoles/{userId}`, holding a single `role` field (the role name
/// string) — e.g. `userRoles/abc123 -> {role: 'admin'}`.
///
/// Unlike the local, shared-prefs-backed implementation, this subscribes to
/// the current user's doc via `snapshots()`, so role changes made by any
/// client/admin/backend process — not just this instance's own [assignRole]
/// calls — propagate to [currentRole] in real time.
class FirestoreUserRoleRepository implements UserRoleRepository {
  /// Creates a repository persisting via [firestore], tracking the current
  /// user via [userIdStream]. [rolePermissions] defaults to
  /// [defaultRolePermissions]; [knownRoles] defaults to [AppRole.defaults]
  /// and is used to resolve a persisted role name back to an [AppRole].
  FirestoreUserRoleRepository({
    required FirebaseFirestore firestore,
    required Stream<String?> userIdStream,
    Map<String, Set<Permission>>? rolePermissions,
    List<AppRole> knownRoles = AppRole.defaults,
  }) : _firestore = firestore,
       _rolePermissions = rolePermissions ?? defaultRolePermissions,
       _knownRoles = knownRoles,
       _cachedRole = AppRole.guest {
    _subscription = userIdStream.listen(_onUserIdChanged);
  }

  final FirebaseFirestore _firestore;
  final Map<String, Set<Permission>> _rolePermissions;
  final List<AppRole> _knownRoles;
  final StreamController<AppRole> _controller =
      StreamController<AppRole>.broadcast();

  late final StreamSubscription<String?> _subscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSubscription;

  AppRole _cachedRole;

  /// Releases the subscriptions to the user id stream and the current
  /// per-user doc, and closes the role controller.
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_docSubscription?.cancel());
    unawaited(_controller.close());
  }

  DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      _firestore.collection('userRoles').doc(userId);

  void _onUserIdChanged(String? userId) {
    unawaited(_docSubscription?.cancel());
    _docSubscription = null;
    if (userId == null) {
      _emitIfChanged(AppRole.guest);
      return;
    }
    _docSubscription = _doc(userId).snapshots().listen((snapshot) {
      final storedName = snapshot.data()?['role'] as String?;
      _emitIfChanged(_resolveRole(storedName));
    });
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
        // No manual emit here: the live snapshot listener set up in
        // `_onUserIdChanged` (if `userId` is the currently-active user) picks
        // up this write and emits naturally, since Firestore pushes doc
        // changes to active listeners. That's the whole point of the
        // DB-backed implementation over the local one, which has no push
        // notifications and must emit manually.
        await _doc(userId).set(<String, dynamic>{
          'role': role.name,
        }, SetOptions(merge: true));
      });
}
