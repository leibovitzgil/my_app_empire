// Registrations are appended by `create_feature/create_package --wire`, so they
// are written as standalone statements rather than a cascade.
// ignore_for_file: cascade_invocations
import 'package:audio/audio.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/fake_deep_link_service.dart';
import 'package:duet/data/mock_auth_repository.dart';
import 'package:duet/data/recording_path_builder.dart';
import 'package:duet/domain/duet_roles.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:get_it/get_it.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monetization/monetization.dart';
import 'package:notifications/notifications.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';
import 'package:review_sync/review_sync.dart';
import 'package:user_roles/user_roles.dart';

/// The app's service locator.
final GetIt getIt = GetIt.instance;

/// Registers every dependency duet composes. This is the canonical wiring
/// pattern: register a concrete implementation against the contract that
/// features depend on, so swapping (mock vs. real) happens in one place.
Future<void> configureDependencies() async {
  final storage = await LocalStorageService.init();
  getIt.registerSingleton<LocalStorageService>(storage);

  getIt.registerLazySingleton<AuthRepository>(MockAuthRepository.new);

  // Eager singletons: both must subscribe to `AuthRepository.user` before
  // the user can possibly log in (see `CurrentUser`'s doc) — a lazy
  // singleton resolved for the first time *after* login would miss that
  // first (and, for a returning session's persisted role, defining) emission
  // on the broadcast stream.
  final currentUser = CurrentUser(getIt<AuthRepository>().user);
  getIt.registerSingleton<CurrentUser>(currentUser);

  getIt.registerSingleton<UserRoleRepository>(
    LocalUserRoleRepository(
      storage: getIt<LocalStorageService>(),
      userIdStream: getIt<AuthRepository>().user,
      rolePermissions: DuetRoles.rolePermissions,
      knownRoles: DuetRoles.knownRoles,
    ),
  );

  getIt.registerLazySingleton<MonetizationService>(
    SimulatedMonetizationService.new,
  );

  // Lazy-async and never awaited/consumed anywhere in this MVP: no screen
  // requests a notification permission yet, and `review_sync`'s own
  // `ReviewSyncNotifier` hook (see `FileShareReviewSyncService`) has nothing
  // to call it with — `NotificationsManager` only wraps FCM permission
  // flows, with no local-notification API. Registered per the DI plan
  // anyway so the contract has a binding; left unconsumed is a real,
  // documented gap for a later phase.
  getIt.registerLazySingletonAsync<NotificationsManager>(
    NotificationsManager.create,
  );

  getIt.registerLazySingleton<PdfRenderService>(PdfxRenderService.new);
  getIt.registerLazySingleton<AudioRecorderService>(
    RecordAudioRecorderService.new,
  );
  getIt.registerLazySingleton<AudioPlayerService>(JustAudioPlayerService.new);
  getIt.registerLazySingleton<AudioAssetStore>(LocalAudioAssetStore.new);
  // Lazy-async, like every other service that eventually touches the
  // filesystem: resolving the recordings temp directory only when the Score
  // Viewer is first opened (see `DuetScorePage`) means a filesystem hiccup
  // only breaks the recording feature, not the app's entire boot sequence.
  getIt.registerLazySingletonAsync<RecordingPathBuilder>(
    createRecordingPathBuilder,
  );

  // `PieceRepository`/`AnnotationRepository` have a constructor cycle:
  // `LocalPieceRepository` needs an `AnnotationRepository` (to purge a
  // deleted piece's annotations) and `LocalAnnotationRepository` needs a
  // `PieceRepository` (to resolve a new author's teacher/student role). The
  // Piece side takes a *lazy provider* rather than a direct instance,
  // breaking the cycle: whichever of the two get_it resolves first fully
  // constructs (caching itself as the singleton) before the other's factory
  // below ever calls back into it.
  getIt.registerLazySingleton<PieceRepository>(
    () => LocalPieceRepository(
      storage: getIt<LocalStorageService>(),
      currentUserId: getIt<CurrentUser>().call,
      pdfRenderService: getIt<PdfRenderService>(),
      annotationRepository: getIt.call<AnnotationRepository>,
      audioAssetStore: getIt<AudioAssetStore>(),
    ),
  );
  getIt.registerLazySingleton<AnnotationRepository>(
    () => LocalAnnotationRepository(
      storage: getIt<LocalStorageService>(),
      currentUserId: getIt<CurrentUser>().call,
      pieceRepository: getIt<PieceRepository>(),
    ),
  );

  getIt.registerLazySingleton<ReviewSyncService>(
    () => FileShareReviewSyncService(
      pieceRepository: getIt<PieceRepository>(),
      annotationRepository: getIt<AnnotationRepository>(),
      audioAssetStore: getIt<AudioAssetStore>(),
      storage: getIt<LocalStorageService>(),
      currentUserId: getIt<CurrentUser>().call,
    ),
  );

  getIt.registerLazySingleton<InviteService>(
    () => DeepLinkInviteService(
      pieceRepository: getIt<PieceRepository>(),
      monetizationService: getIt<MonetizationService>(),
      storage: getIt<LocalStorageService>(),
    ),
  );

  getIt.registerLazySingleton<DeepLinkService>(FakeDeepLinkService.new);
  // generated:register — `create_feature/create_package --wire duet` adds
  // registrations above this line. Do not remove this marker.
}
