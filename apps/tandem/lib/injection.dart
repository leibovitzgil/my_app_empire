// Registrations are appended by `create_feature/create_package --wire`, so they
// are written as standalone statements rather than a cascade.
// ignore_for_file: cascade_invocations
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get_it/get_it.dart';
import 'package:local_storage/local_storage.dart';
import 'package:tandem/data/mock_auth_repository.dart';
import 'package:tandem/data/tandem_deep_link_parser.dart';
import 'package:user_roles/user_roles.dart';

/// The app's service locator.
final GetIt getIt = GetIt.instance;

/// Registers every dependency Tandem composes. Concrete implementations are
/// bound against the contracts features depend on, so swapping the backend
/// happens here alone.
///
/// With [useFirebase] false (default) one shared [InMemoryGroceryRepository]
/// backs both contracts and simulates real-time sync. With it true, the app
/// runs on a real backend — Cloud Firestore for the list, Realtime Database for
/// presence (whose `onDisconnect()` handles staleness server-side, so no client
/// heartbeat is needed). The Firebase path requires `Firebase.initializeApp()`
/// in `main` and a configured project (see the README).
Future<void> configureDependencies({bool useFirebase = false}) async {
  final storage = await LocalStorageService.init();
  getIt.registerSingleton<LocalStorageService>(storage);
  getIt.registerLazySingleton<AuthRepository>(MockAuthRepository.new);

  if (useFirebase) {
    // FirestoreGroceryRepository implements both the list and membership
    // contracts (items + members live under the same household doc), so one
    // instance is bound against both.
    final grocery = FirestoreGroceryRepository(
      firestore: FirebaseFirestore.instance,
      listId: GrocerySeed.listId,
    );
    getIt.registerSingleton<GroceryRepository>(grocery);
    getIt.registerSingleton<MembershipRepository>(grocery);
    getIt.registerLazySingleton<PresenceRepository>(
      () => FirebasePresenceRepository(
        database: FirebaseDatabase.instance,
        listId: GrocerySeed.listId,
      ),
    );
    getIt.registerLazySingleton<UserRoleRepository>(
      () => FirestoreUserRoleRepository(
        firestore: FirebaseFirestore.instance,
        userIdStream: getIt<AuthRepository>().user,
      ),
    );
  } else {
    // One shared instance backs all three contracts, so a write on any
    // subscriber's stream is seen by all — this is what makes the simulated
    // real-time sync (and the swap to Firebase) work.
    final grocery = InMemoryGroceryRepository();
    getIt.registerSingleton<GroceryRepository>(grocery);
    getIt.registerSingleton<PresenceRepository>(grocery);
    getIt.registerSingleton<MembershipRepository>(grocery);
    getIt.registerLazySingleton<UserRoleRepository>(
      () => LocalUserRoleRepository(
        storage: getIt<LocalStorageService>(),
        userIdStream: getIt<AuthRepository>().user,
      ),
    );
  }
  getIt.registerLazySingleton<DeepLinkService>(
    () => AppLinksDeepLinkService(parser: tandemDeepLinkParser),
  );
  // generated:register — `create_feature/create_package --wire tandem` adds
  // registrations above this line. Do not remove this marker.
}
