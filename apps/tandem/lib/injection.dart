// Registrations are appended by `create_feature/create_package --wire`, so they
// are written as standalone statements rather than a cascade.
// ignore_for_file: cascade_invocations
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:get_it/get_it.dart';
import 'package:local_storage/local_storage.dart';
import 'package:tandem/data/mock_auth_repository.dart';

/// The app's service locator.
final GetIt getIt = GetIt.instance;

/// Registers every dependency Tandem composes. Following the showcase pattern,
/// concrete implementations are bound against the contracts features depend on,
/// so swapping the in-memory repo for a Firestore one happens here alone.
///
/// The single [InMemoryGroceryRepository] instance backs both the grocery and
/// presence contracts — that shared instance is what makes the simulated
/// real-time sync (one writer, many subscribers) work.
Future<void> configureDependencies() async {
  final storage = await LocalStorageService.init();
  getIt.registerSingleton<LocalStorageService>(storage);
  getIt.registerLazySingleton<AuthRepository>(MockAuthRepository.new);
  // One shared instance backs both contracts, so a write on any subscriber's
  // stream is seen by all — this is what makes the simulated real-time sync
  // (and the swap to Firestore) work.
  final grocery = InMemoryGroceryRepository();
  getIt.registerSingleton<GroceryRepository>(grocery);
  getIt.registerSingleton<PresenceRepository>(grocery);
  // generated:register — `create_feature/create_package --wire tandem` adds
  // registrations above this line. Do not remove this marker.
}
