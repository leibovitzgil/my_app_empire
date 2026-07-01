import 'package:feature_auth/feature_auth.dart';
import 'package:injectable/injectable.dart';
import 'package:local_storage/local_storage.dart';
import 'package:user_roles/user_roles.dart';

/// Provides [LocalStorageService] (async, shared-prefs backed) and binds
/// [LocalUserRoleRepository] against [UserRoleRepository], deriving its
/// user id stream from the registered [AuthRepository].
@module
abstract class UserRoleModule {
  /// Initializes the shared-preferences-backed storage service. Resolved
  /// before the container is built, since [LocalStorageService.init] is
  /// async.
  @preResolve
  Future<LocalStorageService> get localStorageService =>
      LocalStorageService.init();

  /// Binds a [LocalUserRoleRepository] against [UserRoleRepository], backed
  /// by [storage] and tracking the signed-in user via [auth]'s user stream.
  @LazySingleton(as: UserRoleRepository)
  LocalUserRoleRepository userRoleRepository(
    LocalStorageService storage,
    AuthRepository auth,
  ) => LocalUserRoleRepository(storage: storage, userIdStream: auth.user);
}
