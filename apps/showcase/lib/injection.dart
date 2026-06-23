// Registrations are appended by `create_feature/create_package --wire`, so they
// are written as standalone statements rather than a cascade.
// ignore_for_file: cascade_invocations
import 'package:feature_auth/feature_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monetization/monetization.dart';
import 'package:showcase/data/mock_auth_repository.dart';

/// The app's service locator.
final GetIt getIt = GetIt.instance;

/// Registers every dependency the showcase composes. This is the canonical
/// wiring pattern: register a concrete implementation against the contract that
/// features depend on, so swapping (mock vs. real) happens in one place.
Future<void> configureDependencies() async {
  final storage = await LocalStorageService.init();
  getIt.registerSingleton<LocalStorageService>(storage);
  getIt.registerLazySingleton<AuthRepository>(MockAuthRepository.new);
  getIt.registerLazySingleton<MonetizationService>(
    SimulatedMonetizationService.new,
  );
  // generated:register — `create_feature/create_package --wire showcase` adds
  // registrations above this line. Do not remove this marker.
}
