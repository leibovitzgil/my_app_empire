// Registrations are appended by `create_feature/create_package --wire`, so they
// are written as standalone statements rather than a cascade.
// ignore_for_file: cascade_invocations
import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:app_updater/app_updater.dart';
import 'package:audio/audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crash_reporting/crash_reporting.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/data/account_purge.dart';
import 'package:duet/data/audio_upload_queue.dart';
import 'package:duet/data/callable_account_purge.dart';
import 'package:duet/data/callable_collaborator_invite_service.dart';
import 'package:duet/data/callable_invite_service.dart';
import 'package:duet/data/callable_nudge_service.dart';
import 'package:duet/data/callable_user_directory.dart';
import 'package:duet/data/cloud_audio_asset_store.dart';
import 'package:duet/data/crash_reporter_user_binder.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/current_user_email.dart';
import 'package:duet/data/current_user_name.dart';
import 'package:duet/data/directory_publisher.dart';
import 'package:duet/data/duet_analytics.dart';
import 'package:duet/data/duet_analytics_observer.dart';
import 'package:duet/data/duet_notification_permission_gateway.dart';
import 'package:duet/data/fake_deep_link_service.dart';
import 'package:duet/data/firebase_audio_object_store.dart';
import 'package:duet/data/firebase_piece_binary_store.dart';
import 'package:duet/data/firestore_annotation_repository.dart';
import 'package:duet/data/firestore_piece_repository.dart';
import 'package:duet/data/firestore_piece_sync_monitor.dart';
import 'package:duet/data/local_piece_migrator.dart';
import 'package:duet/data/mock_auth_repository.dart';
import 'package:duet/data/recording_path_builder.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:duet/review_sync/review_sync.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monetization/monetization.dart';
import 'package:notifications/notifications.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:remote_config/remote_config.dart';
import 'package:review_prompter/review_prompter.dart';
import 'package:user_directory/user_directory.dart';

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

  getIt.registerLazySingleton<MonetizationService>(
    SimulatedMonetizationService.new,
  );

  // Remote-config flags (M6.4): consumers pull via the `RemoteConfigService`
  // contract only (G3). BOTH branches currently bind the committed-defaults
  // in-memory fake — `FirebaseRemoteConfigService` needs a real
  // `Firebase.initializeApp` with real project options, which is Track B
  // (M0.2); the emulator suite has no Remote Config emulator either, so
  // binding the fake under `useFirebase` too keeps every composition's flag
  // behavior defined (kill-switches enabled) instead of crashing on an
  // uninitialized Firebase app.
  // TODO(track-b): under `useFirebase`, bind `FirebaseRemoteConfigService`
  // and `await init()` after `Firebase.initializeApp` lands real options
  // (M0.2), then flip the staging console flag to verify (M6.4 ▸B).
  final remoteConfigService = InMemoryRemoteConfigService();
  await remoteConfigService.init();
  getIt.registerSingleton<RemoteConfigService>(remoteConfigService);

  // Force-update gate (M7.6): `ForceUpdateWidget` (app.dart) asks this
  // service whether the running version is below the remote minimum. It
  // consumes the `RemoteConfigService` contract bound above — one config
  // pipeline, no Firebase object of its own — so with the in-memory
  // defaults (`min_supported_version: 0.0.0`) it can never block, keeping
  // the headless gate green (G2). Track B changes behavior by binding the
  // real config service above, not by touching this registration.
  getIt.registerLazySingleton<AppUpdateService>(
    () => AppUpdateService(remoteConfig: getIt<RemoteConfigService>()),
  );

  // Review prompting (M7.6): opens are counted in the real entry points
  // (`main.dart` / `main_emulator.dart`), and the "saved a note" happy
  // moment logs the core action (see `DuetScorePage`). Lazy-async like
  // `NotificationsManager`: construction touches the SharedPreferences
  // platform channel, so nothing on the headless gate ever resolves it
  // (G2 — the M7.1 keep-platform-channels-behind-a-seam precedent).
  getIt.registerLazySingletonAsync<ReviewPrompter>(ReviewPrompter.create);

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
    // Discovery goes through the rate-limited `lookupEmail` callable (M2.5) —
    // the rules now allow a client to read only its own `usersByEmail` entry.
    // The direct-Firestore directory still backs `upsertSelf` (a self-doc
    // write the rules allow); `CallableUserDirectory` wraps it and overrides
    // the lookup.
    final firestoreUserDirectory = FirestoreUserDirectory(
      firestore: FirebaseFirestore.instance,
    );
    getIt.registerSingleton<UserDirectory>(
      CallableUserDirectory(
        local: firestoreUserDirectory,
        functions: FirebaseFunctions.instanceFor(region: duetFunctionsRegion),
      ),
    );

    final firestoreUserMessaging = FirestoreUserMessaging(
      firestore: FirebaseFirestore.instance,
    );
    getIt.registerSingleton<DeviceTokenRegistry>(firestoreUserMessaging);
    getIt.registerSingleton<UserMessageGateway>(firestoreUserMessaging);
    getIt.registerSingleton<InboxNotificationBridge>(
      InboxNotificationBridge(
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
            uid: 'demo_friend_1',
            email: 'friend@duet.dev',
            displayName: 'Demo Friend',
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

  // Crash reporting (M7.1). Both compositions bind the no-op today: the
  // headless/mock path must never construct a Firebase object (G2), and the
  // emulator suite has no Crashlytics emulator to report to. The uid binder
  // below still runs against it, so the glue is exercised end-to-end.
  // TODO(M7.1-B): in the real Firebase entry point (Track B, after M0.2),
  // bind CrashlyticsCrashReporter and call installCrashHooks(reporter)
  // there — never here, and never for mock/emulator runs.
  getIt.registerLazySingleton<CrashReporter>(NoopCrashReporter.new);

  // Eager, like CurrentUser/DirectoryPublisher below: the account
  // subscription must exist before the user can possibly sign in. Uid only —
  // never the email (see the class doc); cleared (null) on sign-out.
  getIt.registerSingleton<CrashReporterUserBinder>(
    CrashReporterUserBinder(
      reporter: getIt<CrashReporter>(),
      accounts: getIt<AuthAccountProvider>().account,
    ),
  );

  // Keeps this device's own directory entry current whenever the signed-in
  // identity changes, threading the locally-stored `discoverable` choice
  // into every upsert (M1.6's clobber fix — see the class doc). Eager, like
  // `CurrentUser`: the account subscription must exist before login can
  // happen. Backend-agnostic on purpose: the mock flow exercises the same
  // publication path the Firestore-backed one uses.
  getIt.registerSingleton<DirectoryPublisher>(
    DirectoryPublisher(
      directory: getIt<UserDirectory>(),
      storage: getIt<LocalStorageService>(),
      accounts: getIt<AuthAccountProvider>().account,
    ),
  );

  // Server-side account deletion (M1.9): the Firebase branch calls the
  // `deleteAccount` callable (M1.8) on the region-pinned Functions
  // instance; the default branch simulates success — the mock identity has
  // no server state to purge. Lazy on purpose: only Settings' danger-zone
  // flow ever resolves it.
  if (useFirebase) {
    getIt.registerLazySingleton<AccountPurge>(
      () => CallableAccountPurge(
        functions: FirebaseFunctions.instanceFor(
          region: duetFunctionsRegion,
        ),
      ),
    );
  } else {
    getIt.registerLazySingleton<AccountPurge>(MockAccountPurge.new);
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

  getIt.registerLazySingleton<PdfRenderService>(PdfrxRenderService.new);
  getIt.registerLazySingleton<AudioRecorderService>(
    RecordAudioRecorderService.new,
  );
  getIt.registerLazySingleton<AudioPlayerService>(JustAudioPlayerService.new);
  // Audio-note asset storage. The default composition keeps notes on-device
  // (`LocalAudioAssetStore`, a flat `audio_notes/` dir); under Firebase they
  // live in Storage (`pieces/{id}/audio/{assetId}`) behind an offline upload
  // queue (M3.5). The queue is a singleton so M4.1's sync badge can later read
  // its pending count from the same instance the store drains.
  if (useFirebase) {
    getIt.registerSingleton<AudioUploadQueue>(
      AudioUploadQueue(storage: getIt<LocalStorageService>()),
    );
    getIt.registerLazySingleton<AudioAssetStore>(
      () => CloudAudioAssetStore(
        objectStore: FirebaseAudioObjectStore(
          storage: FirebaseStorage.instance,
        ),
        uploadQueue: getIt<AudioUploadQueue>(),
      ),
    );
  } else {
    getIt.registerLazySingleton<AudioAssetStore>(LocalAudioAssetStore.new);
  }
  // Lazy-async, like every other service that eventually touches the
  // filesystem: resolving the recordings temp directory only when the Score
  // Viewer is first opened (see `DuetScorePage`) means a filesystem hiccup
  // only breaks the recording feature, not the app's entire boot sequence.
  getIt.registerLazySingletonAsync<RecordingPathBuilder>(
    createRecordingPathBuilder,
  );

  // `PieceRepository`/`AnnotationRepository`: the default composition keeps
  // pieces on-device (the local repositories, which own their binaries); under
  // Firebase (M3.6) they move to Cloud Firestore — real-time reads scoped to
  // the caller's pieces, one ink layer document per author.
  //
  // The local pair has a constructor cycle: `LocalPieceRepository` needs an
  // `AnnotationRepository` (to purge a deleted piece's annotations) and
  // `LocalAnnotationRepository` needs a `PieceRepository` (to resolve a new
  // author's owner/collaborator role). The piece side takes a *lazy provider*
  // rather than a direct instance, breaking the cycle: whichever get_it
  // resolves first fully constructs (caching itself as the singleton) before
  // the other's factory calls back into it. The Firestore pair has no such
  // cycle (neither repository reads the other), so they register directly.
  if (useFirebase) {
    getIt.registerLazySingleton<PieceRepository>(
      () => FirestorePieceRepository(
        firestore: FirebaseFirestore.instance,
        currentUserId: getIt<CurrentUser>().call,
        pdfRenderService: getIt<PdfRenderService>(),
        storage: getIt<LocalStorageService>(),
      ),
    );
    getIt.registerLazySingleton<AnnotationRepository>(
      () => FirestoreAnnotationRepository(
        firestore: FirebaseFirestore.instance,
        currentUserId: getIt<CurrentUser>().call,
      ),
    );
  } else {
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
  }

  // Live reader sync signal (M4.1): the top-bar badge and Layers-panel prompt
  // reflect real persistence state instead of a session-local flag. The
  // default composition is always-synced (the on-device store has no remote to
  // fall behind — and it keeps the headless gate Firebase-free, G2); under
  // Firebase the monitor folds the piece's layers/notes snapshot metadata
  // (pending writes + server reachability) and the M3.5 audio upload-queue
  // depth into a `PieceSyncState`.
  if (useFirebase) {
    getIt.registerLazySingleton<PieceSyncMonitor>(
      () => FirestorePieceSyncMonitor(
        firestore: FirebaseFirestore.instance,
        uploadQueue: getIt<AudioUploadQueue>(),
      ),
    );
  } else {
    getIt.registerLazySingleton<PieceSyncMonitor>(LocalPieceSyncMonitor.new);
  }

  // Base-PDF upload on import (M3.3). The default composition keeps binaries
  // on-device (the local repositories own them), so there's nothing to push —
  // NoopPieceBinaryStore (G2: no Firebase object headless). Under Firebase the
  // import flow uploads `pieces/{id}/base.pdf` with progress, matching the
  // Firestore piece repository the branch above now binds.
  if (useFirebase) {
    getIt.registerLazySingleton<PieceBinaryStore>(
      () => FirebasePieceBinaryStore(
        storage: FirebaseStorage.instance,
        firestore: FirebaseFirestore.instance,
      ),
    );
  } else {
    getIt.registerLazySingleton<PieceBinaryStore>(NoopPieceBinaryStore.new);
  }

  // Resolves a piece's base PDF to a readable local path at read time
  // (M3.4) — cache hit, on-device copy, or download-and-verify via the bound
  // `PieceBinaryStore`. Backend-agnostic: the local composition returns the
  // staged on-device path directly, so this stays green headless; the Firebase
  // store gives it real download/offline-cache behaviour under `useFirebase`.
  getIt.registerLazySingleton<PdfBinaryCache>(
    () => DefaultPdfBinaryCache(
      binaryStore: getIt<PieceBinaryStore>(),
      pdfRenderService: getIt<PdfRenderService>(),
      storage: getIt<LocalStorageService>(),
    ),
  );

  // One-time local→cloud migration (M3.6). Only the Firebase composition
  // registers it: `MigrationPrompt` offers it on first cloud sign-in, and its
  // absence is how the default/mock path stays a no-op (G2). The migration
  // *source* is the on-device trio the app wrote to before this sign-in,
  // constructed directly here (get_it now resolves the cloud implementations)
  // over the same local storage — the piece/annotation cycle broken with a
  // lazy provider exactly as the default branch does above. The *sink* is the
  // bound cloud repositories.
  if (useFirebase) {
    getIt.registerLazySingleton<LocalPieceMigrator>(() {
      final localAudio = LocalAudioAssetStore();
      late final LocalAnnotationRepository localAnnotations;
      final localPieces = LocalPieceRepository(
        storage: getIt<LocalStorageService>(),
        currentUserId: getIt<CurrentUser>().call,
        pdfRenderService: getIt<PdfRenderService>(),
        annotationRepository: () => localAnnotations,
        audioAssetStore: localAudio,
      );
      localAnnotations = LocalAnnotationRepository(
        storage: getIt<LocalStorageService>(),
        currentUserId: getIt<CurrentUser>().call,
        pieceRepository: localPieces,
      );
      return LocalPieceMigrator(
        readLocalPieces: () async => localPieces.storedPieces,
        localAnnotations: localAnnotations,
        localAudio: localAudio,
        cloudPieces: getIt<PieceRepository>(),
        cloudAnnotations: getIt<AnnotationRepository>(),
        cloudAudio: getIt<AudioAssetStore>(),
        binaryStore: getIt<PieceBinaryStore>(),
        storage: getIt<LocalStorageService>(),
        currentUserId: getIt<CurrentUser>().call,
      );
    });
  }

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

  // The secondary (tokenized deep-link) invite path. Under Firebase the
  // whole lifecycle is server-authoritative (M5.2): `CallableInviteService`
  // drives the `createInviteToken`/`resolveInviteToken`/`acceptInviteToken`
  // callables against single-use, expiring `/inviteTokens/{token}` docs the
  // rules deny to clients entirely. The headless gate keeps the local
  // mock-path impl, which now enforces the same 14-day expiry (G2).
  getIt.registerLazySingleton<InviteService>(() {
    if (useFirebase) {
      return CallableInviteService(
        functions: FirebaseFunctions.instanceFor(region: duetFunctionsRegion),
      );
    }
    return DeepLinkInviteService(
      pieceRepository: getIt<PieceRepository>(),
      monetizationService: getIt<MonetizationService>(),
      storage: getIt<LocalStorageService>(),
    );
  });

  // The primary (email-based) collaborator invite path; `InviteService`
  // above remains the secondary/fallback (tokenized deep-link) path — both
  // converge on `PieceRepository.addCollaborator`.
  //
  // Under Firebase the send (inbox write) and accept (consume) go through the
  // M2.4 callables — clients can no longer create `userInbox` docs — while the
  // preview/stream and the on-device piece mutation stay local
  // (`CallableCollaboratorInviteService` wraps the default). The headless gate
  // keeps the pure in-memory path (G2).
  getIt.registerLazySingleton<CollaboratorInviteService>(() {
    final local = DefaultCollaboratorInviteService(
      userDirectory: getIt<UserDirectory>(),
      pieceRepository: getIt<PieceRepository>(),
      monetizationService: getIt<MonetizationService>(),
      messageGateway: getIt<UserMessageGateway>(),
    );
    if (!useFirebase) return local;
    return CallableCollaboratorInviteService(
      local: local,
      functions: FirebaseFunctions.instanceFor(region: duetFunctionsRegion),
    );
  });

  // Nudge a piece's other participants ("<name> added notes") — a lightweight
  // ping distinct from an access-granting invite (M4.2). The default sends the
  // nudge `UserMessage` straight through the in-memory gateway (visible on the
  // recipient's inbox stream in-process); under Firebase the send goes through
  // the `sendNudge` callable, since clients can't write `userInbox` directly
  // (M2.4). Both resolve the piece's participants and fan out the same payload.
  getIt.registerLazySingleton<NudgeService>(() {
    if (useFirebase) {
      return CallableNudgeService(
        functions: FirebaseFunctions.instanceFor(region: duetFunctionsRegion),
      );
    }
    return DefaultNudgeService(
      pieceRepository: getIt<PieceRepository>(),
      messageGateway: getIt<UserMessageGateway>(),
      currentUserId: getIt<CurrentUser>().call,
    );
  });

  getIt.registerLazySingleton<DeepLinkService>(FakeDeepLinkService.new);

  // Analytics (M7.2). Funnel events ride the Duet-side typed catalogue
  // (`DuetAnalytics`, `lib/data/duet_analytics.dart` — see its doc for the
  // full instrumentation-seam map) over the factory's generic `AppLogger`.
  // BOTH branches bind the Firebase-free Talker-only logger today:
  // `FirebaseAnalytics.instance` cannot exist without a real
  // `Firebase.initializeApp` (Track B, M0.2), and the emulator suite has no
  // Analytics emulator to receive events anyway — the same precedent as the
  // M6.4 remote-config and M7.1 crash-reporter bindings above (G2). The
  // injected `CrashReporter` keeps the breadcrumb/error glue exercised
  // end-to-end even while analytics itself is local-only.
  // TODO(track-b): under `useFirebase`, bind
  // `AppLogger(analytics: FirebaseAnalytics.instance, ...)` once real
  // project options land (M0.2), then verify the five funnel events in
  // DebugView and seed the console dashboards (M7.2 ▸B).
  getIt.registerLazySingleton<AppLogger>(
    () => AppLogger(crashReporter: getIt<CrashReporter>()),
  );
  getIt.registerLazySingleton<DuetAnalytics>(
    () => DuetAnalytics(getIt<AppLogger>()),
  );

  // The bloc-side funnel-instrumentation seam (G3: feature code stays
  // analytics-free): one app-level BlocObserver translates feature bloc/
  // cubit transitions into catalogue events. Attached here — the one choke
  // point every entry point (main, emulator, screenshot, driver) already
  // funnels through. The router-side half (`DuetRouteObserver`) is attached
  // to the GoRouter in `app.dart`.
  Bloc.observer = DuetAnalyticsObserver(analytics: getIt<DuetAnalytics>());

  // Local-notification taps → the deep-link seam (M5.5): tapping a
  // foreground-bridge notification ingests its payload URI into
  // `DeepLinkService`, and `AppView`'s existing `onIntent → _dispatchIntent`
  // machinery routes it (signed-in: straight to the piece; signed-out: held
  // until login). Only under `useFirebase` — constructing the router
  // resolves `NotificationsManager` (FirebaseMessaging + a platform
  // channel), which the headless gate must never touch (FIX-3, G2); the
  // bridge whose notifications carry the payload only exists there anyway.
  if (useFirebase) {
    getIt.registerSingleton<NotificationTapRouter>(
      NotificationTapRouter(
        // Same deferred-resolution pattern as `DeviceTokenSync`'s
        // `onTokenRefresh` above: the manager is lazy-async, so the tap
        // stream materializes once it's built.
        taps: Stream.fromFuture(
          getIt.getAsync<NotificationsManager>(),
        ).asyncExpand((manager) => manager.onLocalNotificationTap),
        deepLinks: getIt<DeepLinkService>(),
      ),
    );
  }
  // generated:register — `create_feature/create_package --wire duet` adds
  // registrations above this line. Do not remove this marker.
}

/// Routes local-notification tap payloads into the app's deep-link seam
/// (M5.5): each payload that parses as a URI is [DeepLinkService.ingest]ed,
/// after which the normal intent machinery (`AppView`) owns navigation —
/// this class never touches the router. Unparseable payloads are dropped;
/// whether a *parsed* link is recognized is the deep-link parser's call.
///
/// Public only so `test/notification_tap_router_test.dart` can drive it with
/// a fake tap stream + `FakeDeepLinkService`.
@visibleForTesting
class NotificationTapRouter {
  /// Creates a [NotificationTapRouter], subscribing to [taps] immediately.
  NotificationTapRouter({
    required Stream<String> taps,
    required DeepLinkService deepLinks,
  }) : _deepLinks = deepLinks {
    _subscription = taps.listen(_onTap);
  }

  final DeepLinkService _deepLinks;
  late final StreamSubscription<String> _subscription;

  void _onTap(String payload) {
    final uri = Uri.tryParse(payload);
    if (uri == null) return;
    _deepLinks.ingest(uri);
  }

  /// Cancels the tap subscription. Call when the owning scope (e.g. the
  /// app's DI container) is torn down.
  Future<void> dispose() => _subscription.cancel();
}

/// Bridges the generic message inbox for whoever is currently signed in to a
/// foreground/warm-start local notification (FIX-5: the Firebase emulator
/// has no FCM sender and Cloud Functions don't run headless in this
/// container, so the bridge is the only delivery in local development — see
/// `FirestoreUserMessaging.sendToUser`'s doc). Re-subscribes to the
/// message gateway's inbox whenever the signed-in user id changes (e.g.
/// sign-in/out), showing each message at most once per session. Only ever
/// constructed under `useFirebase: true`.
///
/// Push dedupe (the M5.3 strategy, chosen over "bridge only when push
/// permission is denied"): deployed, the `onInboxMessageCreated` Cloud
/// Function delivers each inbox message as a real FCM push and marks the
/// doc `pushed: true` after a successful send. This bridge skips
/// `showLocal` for [UserMessage.pushed] messages — otherwise a message
/// already shown on the recipient's lock screen would be shown again the
/// moment the app foregrounds. A recipient with no usable device tokens
/// (permission denied, token expired) never gets the `pushed` mark, so the
/// bridge stays their delivery path with no client-side permission
/// branching. The one race — a message landing while the app is already
/// foregrounded may reach this listener before the function marks it — is
/// benign: the bridge shows it locally first, and FCM notifications are not
/// auto-displayed by the OS in foreground, so no double there either.
///
/// Surfacing a message is not the same as consuming it. A
/// [UserMessage.requiresAction] message (an invite) stays unread until the
/// user acts, because `read` is what the accept path checks for replay —
/// marking it read here would burn the invite the instant it was notified.
/// Everything else (a nudge) is done once shown, and is marked read so it
/// leaves the inbox for good — including a `pushed` nudge this bridge never
/// shows: the push already delivered it, and consuming it here is what
/// keeps it from riding every later snapshot.
///
/// Public only so `test/inbox_notification_bridge_test.dart` can reach it:
/// this bridge decides whether a message survives being notified, and that
/// call is worth pinning.
@visibleForTesting
class InboxNotificationBridge {
  /// Creates an [InboxNotificationBridge], subscribing to [userId]
  /// immediately.
  InboxNotificationBridge({
    required Stream<String?> userId,
    required UserMessageGateway gateway,
  }) : _gateway = gateway {
    _userIdSubscription = userId.listen(_onUserIdChanged);
  }

  final UserMessageGateway _gateway;
  late final StreamSubscription<String?> _userIdSubscription;
  StreamSubscription<List<UserMessage>>? _inboxSubscription;

  /// Ids already shown this session. An action-required message stays in the
  /// inbox until it's acted on, so it rides every subsequent snapshot —
  /// without this it would re-notify on each one.
  final Set<String> _shownIds = <String>{};

  void _onUserIdChanged(String? uid) {
    final previous = _inboxSubscription;
    _inboxSubscription = null;
    if (previous != null) unawaited(previous.cancel());
    // A different user's inbox is a different set of ids; and re-notifying a
    // still-pending invite on re-sign-in is correct — it *is* still pending.
    _shownIds.clear();
    if (uid == null) return;
    _inboxSubscription = _gateway
        .inboxFor(uid)
        .listen((messages) => unawaited(_showUnshown(uid, messages)));
  }

  /// Shows each not-yet-shown message of [messages] as a local notification,
  /// consuming only those that don't await an action from the user.
  Future<void> _showUnshown(String uid, List<UserMessage> messages) async {
    // `add` returns false for an id already present, so claiming the ids
    // synchronously here keeps a snapshot arriving mid-await from re-showing.
    final fresh = <UserMessage>[
      for (final message in messages)
        if (_shownIds.add(message.id)) message,
    ];
    if (fresh.isEmpty) return;
    final manager = await getIt.getAsync<NotificationsManager>();
    for (final message in fresh) {
      // Already delivered to a device by FCM (`onInboxMessageCreated`) —
      // re-showing it locally would double-notify. See the class doc.
      if (!message.pushed) {
        await manager.showLocal(
          title: message.title,
          body: message.body,
          // Tapping the notification routes to the exact piece (M5.5) —
          // `NotificationTapRouter` ingests this into `DeepLinkService`.
          payload: pieceDeepLinkFor(message),
        );
      }
      if (!message.requiresAction) {
        await _gateway.markRead(uid, message.id);
      }
    }
  }

  /// The `https://duet.app/piece/<pieceId>` deep link for [message]'s piece,
  /// or null when the message isn't about one — the same URI shape M5.3's
  /// `onInboxMessageCreated` function emits as FCM `data.deepLink` (keep the
  /// two in sync; the domain is that function's `DEEP_LINK_DOMAIN`
  /// placeholder until the product one lands, Track B).
  @visibleForTesting
  static String? pieceDeepLinkFor(UserMessage message) {
    final pieceId = message.data['pieceId'];
    if (pieceId == null || pieceId.isEmpty) return null;
    return 'https://duet.app/piece/${Uri.encodeComponent(pieceId)}';
  }

  /// Cancels both subscriptions. Call when the owning scope (e.g. the app's
  /// DI container) is torn down.
  Future<void> dispose() async {
    await _userIdSubscription.cancel();
    await _inboxSubscription?.cancel();
  }
}
