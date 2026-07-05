// Registrations are appended by `create_feature/create_package --wire`, so they
// are written as standalone statements rather than a cascade.
// ignore_for_file: cascade_invocations
import 'dart:async';

import 'package:audio/audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/current_user_email.dart';
import 'package:duet/data/current_user_name.dart';
import 'package:duet/data/duet_notification_permission_gateway.dart';
import 'package:duet/data/fake_deep_link_service.dart';
import 'package:duet/data/mock_auth_repository.dart';
import 'package:duet/data/recording_path_builder.dart';
import 'package:duet/domain/duet_roles.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:get_it/get_it.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monetization/monetization.dart';
import 'package:notifications/notifications.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';
import 'package:review_sync/review_sync.dart';
import 'package:user_directory/user_directory.dart';
import 'package:user_roles/user_roles.dart';

/// The app's service locator.
final GetIt getIt = GetIt.instance;

/// Registers every dependency duet composes. This is the canonical wiring
/// pattern: register a concrete implementation against the contract that
/// features depend on, so swapping (mock vs. real) happens in one place.
///
/// With [useFirebase] false (default, and what the standard headless test
/// gate always uses) every backend seam this feature added — identity,
/// email directory, device-token registry, message gateway — is bound to an
/// in-memory fake; nothing here ever constructs a Firebase object. With it
/// true, the app runs against real Firebase Auth + Cloud Firestore (see
/// `lib/main_emulator.dart`, which points those at the local emulator suite).
Future<void> configureDependencies({bool useFirebase = false}) async {
  final storage = await LocalStorageService.init();
  getIt.registerSingleton<LocalStorageService>(storage);

  // `AuthAccountProvider` is `feature_auth`'s sibling contract to
  // `AuthRepository` that also surfaces email/display name — both
  // `FirebaseAuthRepository` and `MockAuthRepository` implement it, so
  // `CurrentUserName`/`CurrentUserEmail` below (and `feature_pairing`'s
  // email-invite path) are sourced identically regardless of [useFirebase].
  if (useFirebase) {
    final firebaseAuthRepository = FirebaseAuthRepository();
    getIt.registerSingleton<AuthRepository>(firebaseAuthRepository);
    getIt.registerSingleton<AuthAccountProvider>(firebaseAuthRepository);
  } else {
    // Constructed directly (rather than via `AuthRepository.new` as a lazy
    // singleton) so it can also be registered as `AuthAccountProvider`
    // below without resolving two separate instances.
    final mockAuthRepository = MockAuthRepository();
    getIt.registerSingleton<AuthRepository>(mockAuthRepository);
    getIt.registerSingleton<AuthAccountProvider>(mockAuthRepository);
  }

  // Eager singletons: all three must subscribe to `AuthRepository.user`/
  // `AuthAccountProvider.account` before the user can possibly log in (see
  // `CurrentUser`'s doc) — a lazy singleton resolved for the first time
  // *after* login would miss that first (and, for a returning session's
  // persisted role, defining) emission on the broadcast stream.
  final currentUser = CurrentUser(getIt<AuthRepository>().user);
  getIt.registerSingleton<CurrentUser>(currentUser);

  final currentUserName = CurrentUserName(
    getIt<AuthAccountProvider>().account.map((account) => account?.displayName),
  );
  getIt.registerSingleton<CurrentUserName>(currentUserName);

  final currentUserEmail = CurrentUserEmail(
    getIt<AuthAccountProvider>().account.map((account) => account?.email),
  );
  getIt.registerSingleton<CurrentUserEmail>(currentUserEmail);

  if (useFirebase) {
    getIt.registerLazySingleton<UserRoleRepository>(
      () => FirestoreUserRoleRepository(
        firestore: FirebaseFirestore.instance,
        userIdStream: getIt<AuthRepository>().user,
        rolePermissions: DuetRoles.rolePermissions,
        knownRoles: DuetRoles.knownRoles,
      ),
    );
  } else {
    getIt.registerSingleton<UserRoleRepository>(
      LocalUserRoleRepository(
        storage: getIt<LocalStorageService>(),
        userIdStream: getIt<AuthRepository>().user,
        rolePermissions: DuetRoles.rolePermissions,
        knownRoles: DuetRoles.knownRoles,
      ),
    );
  }

  getIt.registerLazySingleton<MonetizationService>(
    SimulatedMonetizationService.new,
  );

  // Lazy-async since it awaits `SharedPreferences.getInstance()`. Now
  // consumed three ways: `NotificationPermissionGateway` below (for the
  // Settings screen's push toggle), `ReviewSyncService`'s `onImported` hook
  // further down (for the "feedback arrived" local notification), and — only
  // under `useFirebase` — the invite-inbox foreground bridge and
  // `DeviceTokenSync`'s real token source.
  getIt.registerLazySingletonAsync<NotificationsManager>(
    NotificationsManager.create,
  );

  getIt.registerLazySingleton<SettingsRepository>(
    () => LocalSettingsRepository(getIt<LocalStorageService>()),
  );

  // `UserDirectory` (email -> account resolution) and `DeviceTokenRegistry`/
  // `UserMessageGateway` (device-token bookkeeping + the generic message
  // inbox `feature_pairing`'s invites ride over) both get the same
  // useFirebase-branched treatment: an in-memory fake by default, a
  // Firestore-backed implementation (bound against BOTH contracts from one
  // shared instance, mirroring `apps/tandem`'s precedent) under
  // `useFirebase: true`.
  if (useFirebase) {
    final firestoreUserDirectory = FirestoreUserDirectory(
      firestore: FirebaseFirestore.instance,
    );
    getIt.registerSingleton<UserDirectory>(firestoreUserDirectory);
    // Keeps this device's own directory entry current whenever the signed-in
    // identity changes, so other users can resolve an invite to this
    // account by email.
    getIt<AuthAccountProvider>().account.listen((account) {
      final email = account?.email;
      if (account == null || email == null) return;
      unawaited(
        _upsertDirectoryEntry(
          firestoreUserDirectory,
          DirectoryUser(
            uid: account.uid,
            email: email,
            displayName: account.displayName,
          ),
        ),
      );
    });

    final firestoreUserMessaging = FirestoreUserMessaging(
      firestore: FirebaseFirestore.instance,
    );
    getIt.registerSingleton<DeviceTokenRegistry>(firestoreUserMessaging);
    getIt.registerSingleton<UserMessageGateway>(firestoreUserMessaging);
    getIt.registerSingleton<_InboxNotificationBridge>(
      _InboxNotificationBridge(
        userId: getIt<AuthRepository>().user,
        gateway: firestoreUserMessaging,
      ),
    );
  } else {
    // A demo/dev-only seed so the "invite a collaborator by email" flow has
    // at least one discoverable account to resolve against when running
    // this (single-process, single-real-identity) mock locally.
    getIt.registerLazySingleton<UserDirectory>(
      () => InMemoryUserDirectory(
        seed: const [
          DirectoryUser(
            uid: 'demo_student_1',
            email: 'student@duet.dev',
            displayName: 'Demo Student',
          ),
        ],
      ),
    );

    // One shared instance backs both contracts (mirroring
    // `apps/tandem`'s shared `InMemoryGroceryRepository`), so an owner's
    // `sendToUser` is immediately visible on the invitee's `inboxFor`
    // stream within this process.
    final inMemoryUserMessaging = InMemoryUserMessaging();
    getIt.registerSingleton<DeviceTokenRegistry>(inMemoryUserMessaging);
    getIt.registerSingleton<UserMessageGateway>(inMemoryUserMessaging);
  }

  // `DeviceTokenSync`'s token source is always injected (FIX-3): the default
  // branch binds a fake that never resolves a token and never rotates, so
  // nothing here reaches for `NotificationsManager`/`FirebaseMessaging`
  // headlessly. Only `useFirebase: true` sources it from the real manager.
  getIt.registerSingleton<DeviceTokenSync>(
    DeviceTokenSync(
      registry: getIt<DeviceTokenRegistry>(),
      currentUserId: getIt<CurrentUser>().call,
      tokenGetter: useFirebase
          ? () async =>
                (await getIt.getAsync<NotificationsManager>()).getToken()
          : () async => null,
      onTokenRefresh: useFirebase
          ? Stream.fromFuture(
              getIt.getAsync<NotificationsManager>(),
            ).asyncExpand((manager) => manager.onTokenRefresh)
          : const Stream<String>.empty(),
    ),
  );

  // Lazy-async, like `NotificationsManager` itself: the gateway can't exist
  // before the manager it wraps does. Threads `DeviceTokenSync` through so a
  // permission grant also registers this device's token (FIX-7) — there's
  // no permission-grant stream to subscribe to instead.
  getIt.registerLazySingletonAsync<NotificationPermissionGateway>(
    () async => DuetNotificationPermissionGateway(
      await getIt.getAsync<NotificationsManager>(),
      deviceTokenSync: getIt<DeviceTokenSync>(),
    ),
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
  // below ever calls back into it. These stay local-only (no Firestore
  // impl) regardless of [useFirebase] — this feature only moved the
  // identity/messaging seams to Firebase, not piece storage itself.
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
      currentUserName: getIt<CurrentUserName>().call,
      // The title/body copy (including the author's name, when known) is
      // already composed by `FileShareReviewSyncService` itself — this hook
      // just has to surface it as a real device notification.
      onImported: ({required title, required body}) async {
        final manager = await getIt.getAsync<NotificationsManager>();
        await manager.showLocal(title: title, body: body);
      },
    ),
  );

  getIt.registerLazySingleton<InviteService>(
    () => DeepLinkInviteService(
      pieceRepository: getIt<PieceRepository>(),
      monetizationService: getIt<MonetizationService>(),
      storage: getIt<LocalStorageService>(),
    ),
  );

  // The primary (email-based) collaborator invite path; `InviteService`
  // above remains the secondary/fallback (tokenized deep-link) path — both
  // converge on `PieceRepository.addCollaborator`.
  getIt.registerLazySingleton<CollaboratorInviteService>(
    () => DefaultCollaboratorInviteService(
      userDirectory: getIt<UserDirectory>(),
      pieceRepository: getIt<PieceRepository>(),
      monetizationService: getIt<MonetizationService>(),
      messageGateway: getIt<UserMessageGateway>(),
    ),
  );

  getIt.registerLazySingleton<DeepLinkService>(FakeDeepLinkService.new);
  // generated:register — `create_feature/create_package --wire duet` adds
  // registrations above this line. Do not remove this marker.
}

/// Publishes [user] to [directory], discarding the `Result` — a
/// best-effort background sync, not something the auth-change listener
/// blocks on or surfaces a failure for.
Future<void> _upsertDirectoryEntry(
  UserDirectory directory,
  DirectoryUser user,
) async {
  await directory.upsertSelf(user);
}

/// Bridges the generic message inbox for whoever is currently signed in to a
/// foreground/warm-start local notification (FIX-5: the Firebase emulator
/// has no FCM sender and Cloud Functions don't run headless in this
/// container, so there is no background push in v1 — see
/// `FirestoreUserMessaging.sendToUser`'s doc). Re-subscribes to the
/// message gateway's inbox whenever the signed-in user id changes (e.g.
/// sign-in/out), and marks each surfaced message read so it's shown at
/// most once. Only ever constructed under `useFirebase: true`.
class _InboxNotificationBridge {
  /// Creates an [_InboxNotificationBridge], subscribing to [userId]
  /// immediately.
  _InboxNotificationBridge({
    required Stream<String?> userId,
    required UserMessageGateway gateway,
  }) : _gateway = gateway {
    _userIdSubscription = userId.listen(_onUserIdChanged);
  }

  final UserMessageGateway _gateway;
  late final StreamSubscription<String?> _userIdSubscription;
  StreamSubscription<List<UserMessage>>? _inboxSubscription;

  void _onUserIdChanged(String? uid) {
    final previous = _inboxSubscription;
    _inboxSubscription = null;
    if (previous != null) unawaited(previous.cancel());
    if (uid == null) return;
    _inboxSubscription = _gateway
        .inboxFor(uid)
        .listen((messages) => unawaited(_showAndMarkRead(uid, messages)));
  }

  /// Shows each of [messages] as a local notification and marks it read, so
  /// a message the inbox has already surfaced isn't shown again on the next
  /// snapshot.
  Future<void> _showAndMarkRead(String uid, List<UserMessage> messages) async {
    if (messages.isEmpty) return;
    final manager = await getIt.getAsync<NotificationsManager>();
    for (final message in messages) {
      await manager.showLocal(title: message.title, body: message.body);
      await _gateway.markRead(uid, message.id);
    }
  }

  /// Cancels both subscriptions. Call when the owning scope (e.g. the app's
  /// DI container) is torn down.
  Future<void> dispose() async {
    await _userIdSubscription.cancel();
    await _inboxSubscription?.cancel();
  }
}
