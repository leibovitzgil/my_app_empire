// Registrations are appended by `create_feature/create_package --wire`, so they
// are written as standalone statements rather than a cascade.
// ignore_for_file: cascade_invocations
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/data/fake_deep_link_service.dart';
import 'package:duet/data/mock_auth_repository.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:local_storage/local_storage.dart';
import 'package:user_roles/user_roles.dart';

/// The app's service locator.
final GetIt getIt = GetIt.instance;

/// Registers every dependency duet composes. This is the canonical wiring
/// pattern: register a concrete implementation against the contract that
/// features depend on, so swapping (mock vs. real) happens in one place.
Future<void> configureDependencies() async {
  final storage = await LocalStorageService.init();
  getIt.registerSingleton<LocalStorageService>(storage);
  getIt.registerLazySingleton<DeepLinkService>(FakeDeepLinkService.new);
  getIt.registerLazySingleton<AuthRepository>(MockAuthRepository.new);
  getIt.registerLazySingleton<UserRoleRepository>(
    () => LocalUserRoleRepository(
      storage: getIt<LocalStorageService>(),
      userIdStream: getIt<AuthRepository>().user,
    ),
  );
  // generated:register — `create_feature/create_package --wire duet` adds
  // registrations above this line. Do not remove this marker.
}
