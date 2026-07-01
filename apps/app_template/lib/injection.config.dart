// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:deep_linking/deep_linking.dart' as _i904;
import 'package:feature_auth/feature_auth.dart' as _i277;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:local_storage/local_storage.dart' as _i486;
import 'package:user_roles/user_roles.dart' as _i423;

import 'data/fake_deep_link_service.dart' as _i25;
import 'data/mock_auth_repository.dart' as _i151;
import 'data/user_role_repository_module.dart' as _i343;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final userRoleModule = _$UserRoleModule();
    await gh.factoryAsync<_i486.LocalStorageService>(
      () => userRoleModule.localStorageService,
      preResolve: true,
    );
    gh.lazySingleton<_i904.DeepLinkService>(() => _i25.FakeDeepLinkService());
    gh.lazySingleton<_i277.AuthRepository>(() => _i151.MockAuthRepository());
    gh.lazySingleton<_i423.UserRoleRepository>(
      () => userRoleModule.userRoleRepository(
        gh<_i486.LocalStorageService>(),
        gh<_i277.AuthRepository>(),
      ),
    );
    return this;
  }
}

class _$UserRoleModule extends _i343.UserRoleModule {}
