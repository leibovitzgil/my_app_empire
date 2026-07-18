# Duet — Granular Implementation Breakdown

A task-level decomposition of [duet_production_plan.md](duet_production_plan.md).
Each task below is sized to be handed to an agent **as one unit of work**
(one green PR, occasionally a small series). Tasks carry their own context,
concrete file/class references, steps, and exit criteria, so an agent can
implement a single section without re-deriving the whole plan.

Grounded in the codebase as of `ee76c5d` (post PR #50/#51). File references
were verified against source; line numbers are approximate anchors, not
promises.

Work is split into **Track A (emulator-first — start now)** and **Track B
(name-gated)** — see "Two tracks" below — so building proceeds against the
local emulators while the product name, and with it every irreversible
identifier, stays undecided.

## How to use this document

1. Pick the lowest-numbered unblocked task **from Track A** (see the
   two-track index and each task's **Depends on**); Track B stays parked
   until the product name is decided.
2. Hand the agent the whole task section, plus the **Working agreements**
   below. A prompt template:

   > Implement task **M3.2** from `docs/duet_implementation_breakdown.md`.
   > Read that section and the "Working agreements" section first, then the
   > files it cites. Follow the factory pipeline (architect → flutter-builder
   > → qa-engineer → code-reviewer) as appropriate. Keep the workspace gate
   > green and stop at the task's "Done when" — do not pull in later tasks.

3. Tasks tagged **[HUMAN]** need console/store/DNS/account access an agent
   does not have. Do them (or their listed outputs) before the tasks that
   depend on them.
4. Check off tasks in the index as they merge. If implementation deviates
   from a task, edit the task text in the same PR so this document stays
   true.

## Working agreements (G-rules — cited from tasks)

- **G1 — Green gate.** Every task ends with
  `melos bootstrap && melos run format-check && melos run lint && melos run test`
  green across the workspace, plus `melos run golden` when UI changed.
- **G2 — The headless gate stays mocked.** `configureDependencies()`
  (no args) in `apps/duet/lib/injection.dart` must never construct a
  Firebase object; `apps/duet/test/injection_test.dart` is the guardrail
  and must keep passing untouched-in-spirit. Emulator/device tests are
  opt-in (`melos run e2e`), never part of `melos run test`.
- **G3 — Contracts are the seam.** Blocs and UI depend on the abstract
  contracts (`PieceRepository`, `AnnotationRepository`, `AudioAssetStore`,
  `AuthRepository`, `UserDirectory`, `UserMessageGateway`,
  `MonetizationService`, `DeepLinkService`, …). New backends are new
  implementations behind existing contracts; a task that must widen a
  contract says so explicitly and updates every implementation (including
  in-memory/mock ones) and every consuming app (`duet`, `app_template`,
  `showcase`) in the same PR.
- **G4 — Failures ride `Result`.** Repos/services return
  `Future<Result<T>>` (`core_utils`). Blocking failures render
  `ErrorRetryView`, transient ones `AppSnackbar.error(...)`; blocs fold
  failures into `status`/`error` fields (see `ScoreBloc`, `SettingsBloc`
  for the pattern).
- **G5 — Factory conventions.** `very_good_analysis` strictness, single
  quotes, trailing commas, ≤80-char lines, barrel files export public API
  only. New packages via `dart run tool/create_package.dart <name>
  [--layer services] [--wire duet]`, not by hand.
- **G6 — Rules before client writes.** No client code ships that writes a
  Firestore collection whose rules + rules-tests haven't landed (M2 exit
  discipline, applied everywhere).
- **G7 — Server-authoritative where trust matters.** Cross-user mutations
  (invite delivery/acceptance, purge, entitlement-gated caps) go through
  Cloud Functions; client-side checks remain for UX only.
- **G8 — Routing standard.** Every full-screen destination in an app is a
  `go_router` route; feature packages never navigate or reference route
  names (callbacks only); the redirect owns auth reachability; deep-link
  intents ride `_dispatchIntent` (go when signed in, held until login
  otherwise). See CLAUDE.md "Routing & navigation";
  `apps/duet/lib/app.dart` is the reference.

## Two tracks: emulator-first now, name-gated later

The product name is undecided, and the name is what locks the truly
irreversible identifiers: the bundle id / applicationId (permanent once
shipped), the Firebase project ids, the invite-link domain, and the
store / RevenueCat records. Everything else runs against the local
Firebase Emulator Suite under the `demo-duet` project id — and the
`demo-*` prefix is an offline guarantee: the CLI never contacts (or
creates) a real Firebase resource for it. The in-repo name `duet` is a
codename and can stay regardless of the final product name.

- **Track A — start now.** Emulator- and fake-backed; no real project,
  no name, no console access needed. Real hardware included:
  `dev_device.sh` already runs a physical iPhone/iPad against the LAN
  emulators.
- **Track B — name-gated.** Everything that embeds the name or needs a
  real project/store, plus the live-verification tail of Track A work.
  The one true emulator blind spot is push: **there is no FCM emulator**,
  so real delivery verification always sits here.

When the name lands: run NAME → M0.H → M0.1 → M0.2 → M0.3 → M0.5, then
burn down the verification backlog below in one focused integration pass
(budget about a week — it is config and verification, not rewrites,
because every backend sits behind a swappable contract).

### Track B verification backlog (the ▸B items)

Deferred live checks for tasks built in Track A, in rough order once
Track B's M0 lands: M2.5 App Check enforcement flip · M4.5 two-device
staging demo · M5.3/M5.4 real FCM delivery (APNs key;
`firebase_messaging` becomes a real dependency) · M5.5 FCM tap-through
wiring · M6.4 staging console flag flip · M7.1 forced crash appears in
Crashlytics · M7.2 DebugView + funnel dashboards · M7.3 perf dashboards ·
M7.4 hosted policy URLs + store privacy forms · M7.5 staging export run ·
M7.6 real Remote Config keys + review-prompt check on staging.

## Task index

Legend: ☐ not started · ☑ done · [HUMAN] needs non-agent access · ▸B =
built in Track A with emulators/fakes, keeps one live-verification step
in the Track B backlog.

### Track A — emulator-first (start now)

| ID | Task | Depends on |
| --- | --- | --- |
| M0.4 | ☑ `firebase.json` deploy targets + Functions scaffold | — |
| M1.1 | ☑ Auth error taxonomy over `Result` | — |
| M1.2 | ☑ Email/password sign-up | M1.1 |
| M1.3 | ☑ Password reset + email verification | M1.2 |
| M1.4 | ☑ Re-authentication for sensitive ops | M1.1 |
| M1.5 | ☑ Profile: display-name editing + sign-out in Settings | M1.1 |
| M1.6 | ☑ `discoverable` toggle (and stop clobbering it) | M1.5 |
| M1.7 | ☑ Rules-test harness (npm) + current-rules coverage | M0.4 |
| M1.8 | ☑ Account deletion: purge Function v1 | M0.4, M1.4 |
| M1.9 | ☑ Account deletion: client flow in Settings | M1.8, M1.5 |
| M1.10 | ☑ Auth lifecycle emulator E2E | M1.2–M1.9 |
| M2.1 | ☑ Cloud schema design doc (pieces) | — |
| M2.2 | ☑ `firestore.rules` + `storage.rules` + indexes for pieces | M2.1 |
| M2.3 | ☑ Rules tests for pieces/layers/notes/reads + Storage | M2.2, M1.7 |
| M2.4 | ☑ Invite lifecycle server-side (send/accept/leave callables) | M2.2, M0.4 |
| M2.5 | ☑ ▸B Directory lookup hardening (callable + rate limit) | M2.4 (enforce flip: M0.3) |
| M3.1 | ☑ `FirestorePieceRepository` | M2.2, M2.3 |
| M3.2 | ☑ `FirestoreAnnotationRepository` | M3.1 |
| M3.3 | ☑ PDF upload on import (checksum dedupe + progress UI) | M3.1 |
| M3.4 | ☑ Binary download/cache manager (offline reading) | M3.3 |
| M3.5 | ☑ `CloudAudioAssetStore` + offline upload queue | M3.2 |
| M3.6 | ☑ DI flip + one-time local→cloud migration | M3.1–M3.5 |
| M3.7 | ☑ Per-user last-opened watermark + real unread signal | M3.1, M2.2 |
| M3.8 | ☑ Delete cascade Function + purge v2 + cloud-pieces E2E | M3.6, M1.8 |
| M4.1 | ☑ Real `ScoreSyncStatus` from repository state | M3.2 |
| M4.2 | ☑ Demote bundles; "nudge collaborator" affordances | M4.1 |
| M4.3 | ☑ Attention loop: new-annotation + audio-pin "new" markers | M3.7, M4.1 |
| M4.4 | ☑ Soft-delete tombstones for audio notes | M3.2 |
| M4.5 | ☐ ▸B Reader E2E against emulator in CI | M4.1–M4.4, M2.4 |
| M5.2 | ☑ Invite tokens as expiring Firestore docs | M2.4 |
| M5.3 | ☑ ▸B Push fan-out: `onInboxMessageCreated` → FCM + pruning | M2.4, M0.4 |
| M5.4 | ☐ ▸B Batched annotation digest push | M5.3, M3.2 |
| M5.5 | ☑ ▸B Notification tap-through → exact piece | M2.4 (FCM taps: M5.1, M5.3) |
| M5.6 | ☑ In-app invite inbox UI (email-invite acceptance) | M2.4 |
| M6.4 | ☑ ▸B Remote Config package contract + Duet wiring | — (real binding: M0.2) |
| M7.1 | ☑ ▸B New `crash_reporting` service package + wiring | — (live wiring: M0.2) |
| M7.2 | ☑ ▸B Analytics: event catalogue + funnel instrumentation | — (live wiring: M0.2) |
| M7.3 | ☐ ▸B Performance traces on PDF open / page render | M7.1 (dashboards: M0.2) |
| M7.4 | ☐ ▸B Legal surfaces: policy/ToS, consent, store data maps | — |
| M7.5 | ☐ ▸B GDPR self-service data export | M1.8 |
| M7.6 | ☑ ▸B `review_prompter` + `app_updater` wiring | M6.4 |
| M8.1 | ☑ Real page thumbnails + thumbnail cache | — |
| M8.2 | ☐ Large-PDF memory strategy (cache/eviction/zoom scale) | M8.1 |
| M8.3 | ☑ Audio note size caps + compression | — |
| M8.4 | ☐ Failure-mode audit (quota/upload/rules-denied) | M3.6 |
| M8.5 | ☐ Device-matrix QA, a11y pass, l10n decision | M4.5 |
| M9.1 | ☐ CI: full PR gate (melos + rules tests + emulator E2E) | M1.7, M2.3, M4.5 |

### Track B — name-gated (unblocks when the product name is decided)

| ID | Task | Depends on |
| --- | --- | --- |
| NAME | ☐ [HUMAN] Decide the product name → bundle-id root | — |
| M0.H | ☐ [HUMAN] Firebase projects, Blaze, regions, budgets | NAME |
| M0.1 | ☐ Commit real platform folders + flavors | M0.H |
| M0.2 | ☐ `flutterfire configure` ×3 + entry-point restructure | M0.H, M0.1 |
| M0.3 | ☐ App Check (monitoring mode) | M0.2 |
| M0.5 | ☐ CI: firebase deploys + existing workflow fixes | M0.H, M0.4 |
| M5.H | ☐ [HUMAN] Invite-link domain + DNS + store team ids | NAME |
| M5.1 | ☐ Real `DeepLinkService` + Universal/App Links + fallback page | M5.H, M0.2 |
| M5.7 | ☐ Two-device staging validation + `duet-device` skill update | M5.1 + M5.x ▸B items |
| M6.H | ☐ [HUMAN] RevenueCat + store products + API keys | NAME |
| M6.1 | ☐ Wire `RevenueCatService` (flavor-gated) | M6.H, M0.2, M1.1 |
| M6.2 | ☐ Paywall on real offerings + restore + billing states | M6.1 |
| M6.3 | ☐ Server-side entitlements + cap enforcement | M6.1, M2.4 |
| M9.H | ☐ [HUMAN] Signing certs, store listings, demo account | M6.H |
| M9.2 | ☐ Tagged builds → TestFlight / Play internal | M0.2, M9.H |
| M9.3 | ☐ Store screenshot automation | M9.2 |
| M9.4 | ☐ App Review readiness pack | M1.9, M9.H |
| M9.5 | ☐ Launch runbook | M9.1 |

## Open decisions (resolve before the tasks they gate)

| Decision | Gates | Default |
| --- | --- | --- |
| Product name → bundle-id/applicationId root | **All of Track B** (M0.1 first) | `com.<org>.<name>` + `.dev`/`.stg` suffixes; in-repo `duet` stays a codename |
| RevenueCat vs StoreKit2/Play Billing | M6.* | RevenueCat (service class already exists) |
| Invite-link custom domain | M5.H, M5.1 | `link.<app-domain>` |
| Consent mechanism (CMP vs minimal in-house) | M7.4 | Minimal in-house consent record; CMP only if ads/tracking added |
| PDF dedupe scope (per-piece vs global by checksum) | M2.1, M3.3 | Per-piece Storage object; checksum dedupes cache + re-upload only |
| Platform priority | M9.2 | iOS-first, Android fast-follow |
| Hebrew/RTL in 1.0 | M8.5 | English-only 1.0 |

---

## M0 — Firebase foundations & environments

Covers every plan bullet of M0: projects/flavors/entry points (M0.H, M0.1,
M0.2), App Check + regions + budgets (M0.3 + M0.H), CI secrets and deploy
targets for rules/indexes/functions/storage/hosting (M0.4, M0.5).
**Track note:** only M0.4 is Track A — it runs entirely against the
`demo-duet` emulators; the rest of M0 is name-gated Track B.

### M0.H — [HUMAN] Create the Firebase projects & accounts

**Goal:** The three projects exist and an agent can be handed real ids.

- Create `duet-dev`, `duet-staging`, `duet-prod` on the **Blaze** plan.
- Pick and record one region for everything (Firestore, Storage, Functions
  — e.g. `europe-west1`; write it into `docs/duet_cloud_schema.md` later,
  M2.1 references it). Regions are immutable per project — set them when
  enabling each product, not after.
- Enable per project: Auth (Email/Password, Google, Apple), Firestore,
  Storage. Configure budget alerts + usage dashboards on all three.
- Decide the bundle id root (Open decisions) and register iOS/Android apps
  per project (or let `flutterfire configure` do it in M0.2).
- Create a deploy service account per project (or one with roles on all
  three) and add it as the GitHub Actions secret `FIREBASE_SERVICE_ACCOUNT`
  (M0.5 consumes it).
- Google sign-in on Android needs SHA-1/SHA-256 fingerprints registered;
  Apple sign-in needs the capability + Services ID in the Apple developer
  portal (also needed by M1.10, M9.4).

**Done when:** project ids, region, bundle ids, and the CI secret are
recorded in `docs/duet_environments.md` (create it; no secrets in the repo,
only names/ids).

### M0.1 — Commit real platform folders with dev/staging/prod flavors

**Goal:** `apps/duet/android/` and `apps/duet/ios/` exist in git with three
flavors, so `flutterfire configure` (M0.2) has something to write into.

**Context.** Today Duet ships **no** platform dirs: `.gitignore` (lines
~36–46) ignores `apps/duet/{android,ios,web,...}` and `apps/duet/dev.sh`
generates them on demand via `flutter create --platforms=<target>
--project-name duet .`. That convention reverses here: flavored platform
config, `google-services.json`, and `GoogleService-Info.plist` must be
version-controlled. (`apps/tandem/ios/` is a locally-generated tree that
leaked into git, including `Pods/` — treat it as a warning, not a template.)

**Steps**
1. Generate scaffolding (`flutter create --platforms=android,ios
   --project-name duet .` inside `apps/duet`), then delete the generated
   `test/widget_test.dart` (dev.sh already does this — mirror it).
2. Android: set `applicationId` to the decided root; add `productFlavors`
   `dev`/`staging`/`prod` (dimension `env`) with `applicationIdSuffix
   '.dev'` / `'.stg'` / none; matching `resValue` app names ("Duet Dev",
   "Duet β", "Duet").
3. iOS: three schemes/xcconfigs (Debug/Release per env) with distinct
   `PRODUCT_BUNDLE_IDENTIFIER`s and display names; deployment target ≥ 15.0
   (cloud_firestore requirement — the `duet-device` skill documents this).
4. Un-ignore: carve `.gitignore` exceptions for `apps/duet/android/` and
   `apps/duet/ios/` source files while keeping build products ignored
   (`**/Pods/`, `**/.gradle/`, `ephemeral/`, `xcuserdata/` — do NOT commit
   what tandem committed).
5. Update `apps/duet/dev.sh` (platform-generation block, ~lines 78–84) and
   `dev_device.sh` to *skip* generation when the committed dirs exist, and
   update `.claude/skills/duet-emulator/SKILL.md` +
   `.claude/skills/duet-device/SKILL.md` where they state "apps ship
   without platform folders".
6. Nothing here may break the headless gate (G2) — platform dirs are inert
   to `melos run test`.

**Done when:** `flutter build apk --flavor dev` and an iOS build (local
mac, human-assisted) succeed; `./dev.sh` still boots the emulator flow;
gate green (G1); skills/docs updated.

### M0.2 — `flutterfire configure` per flavor + entry-point restructure

**Goal:** `main.dart` boots real Firebase per flavor; the mock boot becomes
`main_mock.dart`; `main_emulator.dart` unchanged.

**Context.** Today `apps/duet/lib/main.dart` is 9 lines of fully-mocked
boot (`configureDependencies()` → `runApp`). The only Firebase init lives
in `main_emulator.dart` (throwaway options, `demo-duet`, emulator ports
9099/8080, `EMU_HOST` dart-define). There are **no** `firebase_options*.dart`
anywhere in the repo. `apps/tandem/lib/main.dart`'s `USE_FIREBASE`
dart-define is prior art but relies on native config only — do not copy it.

**Steps**
1. **[HUMAN-assisted]** Run `flutterfire configure --project=duet-<env>
   --out=lib/firebase_options_<env>.dart` (×3) with the real bundle
   ids/package names from M0.1. Commit the three options files plus the
   per-flavor `google-services.json` (android/app/src/<flavor>/) and
   `GoogleService-Info.plist` (per-scheme).
2. Restructure entry points in `apps/duet/lib/`:
   - `main_mock.dart` ← today's `main.dart` body (mock boot, used by
     humans for offline UI work; the test gate does not use any `main`).
   - `main_dev.dart` / `main_staging.dart` / `main.dart` (prod): each does
     `Firebase.initializeApp(options: <flavor options>.currentPlatform)`
     then `configureDependencies(useFirebase: true)`.
   - Keep `main_emulator.dart` and `main_screenshot.dart` byte-identical
     in behavior.
   - Factor the shared boot into `lib/bootstrap.dart` if duplication
     itches, but keep each entry trivially readable.
3. Keep `configureDependencies({bool useFirebase = false})` default
   `false`; `apps/duet/test/injection_test.dart` must pass unmodified (its
   header comment documents exactly this guardrail) (G2).
4. Wire flavors to entries: `flutter run --flavor dev -t lib/main_dev.dart`
   etc.; document the matrix in `apps/duet/README.md`.
5. Add `--dart-define=FLAVOR=<env>` only if something needs to introspect
   the flavor at runtime (avoid until needed).

**Done when:** `flutter run --flavor staging -t lib/main_staging.dart` on a
device signs in with the real `FirebaseAuthRepository` (injection.dart
lines ~50–61 select it) — this is the **M0 exit criterion**; headless gate
still fully green and mocked (G1, G2).

### M0.3 — App Check in monitoring mode

**Goal:** All three apps attest with Play Integrity / DeviceCheck;
enforcement stays **off** (monitoring) until M2.5 flips it for the
directory.

**Steps**
1. Add `firebase_app_check` to `apps/duet/pubspec.yaml`.
2. In the three real entry points (M0.2), after `initializeApp`:
   `FirebaseAppCheck.instance.activate(androidProvider:
   AndroidProvider.playIntegrity, appleProvider: AppleProvider.deviceCheck)`;
   in `main_dev.dart` and `main_emulator.dart` use the debug providers.
3. **[HUMAN]** Register debug tokens in the console for dev devices;
   verify the App Check metrics dashboards show attested traffic; leave
   enforcement off everywhere.
4. Document the monitoring→enforce plan in `docs/duet_environments.md`.

**Done when:** staging traffic shows as attested in the console; emulator
flow (`./dev.sh`) unaffected; gate green.

### M0.4 — `firebase.json` deploy targets + Functions workspace scaffold

**Goal:** `firebase deploy` from `apps/duet/` can target rules, indexes,
storage rules, functions, and hosting; a `functions/` workspace exists and
builds.

**Track A entry point.** Everything here targets the emulator suite under
`demo-duet`; no real project or product name is needed.

**Context.** `apps/duet/firebase.json` today has only
`firestore.rules` + auth/firestore emulators (9099/8080, bound to
`0.0.0.0`, `ui` disabled). `.firebaserc` maps `default: demo-duet`. There
is **no** functions/storage/hosting config, no `package.json` anywhere in
the repo.

**Steps**
1. Grow `apps/duet/firebase.json`: `firestore.rules` +
   `firestore.indexes.json` (create an empty-valid indexes file now; M2.2
   fills it), `storage.rules` (create a deny-all placeholder now; M2.2
   fills it), `functions` (source `functions/`, runtime nodejs20+),
   `hosting` (public dir `hosting/` with a placeholder page; M5.1 replaces
   it), and emulator entries for `functions`, `storage`, `hosting`
   (keep `0.0.0.0` binding — `dev_device.sh` depends on LAN access).
2. `.firebaserc`: keep `default: demo-duet` (the emulator flow); adding
   the `dev`/`staging`/`prod` aliases is a one-line Track B follow-up
   once M0.H creates the projects.
3. Scaffold `apps/duet/functions/`: TypeScript, `firebase-functions` v2
   APIs, eslint + vitest (or jest), `npm run build|lint|test`, plus one
   trivial callable `healthcheck` proving deploy/emulation. Pin the
   Functions **region** in a shared `region.ts` (the emulator ignores it;
   placeholder until M0.H fixes the real region — leave a TODO).
4. Update `apps/duet/dev.sh`: `--only auth,firestore` grows to
   `auth,firestore,functions,storage` once functions exist; build functions
   before `emulators:start` (npm install/build step with a cache check so
   repeat runs stay fast).
5. Add a melos-adjacent convenience: `melos run functions-test` (or a
   package script documented in README) so CI (M0.5) has one entry point.

**Done when:** `firebase emulators:start` from `apps/duet` boots
auth+firestore+functions+storage+hosting locally; `healthcheck` callable
answers on the emulator; `npm test` green in `functions/`; workspace gate
untouched (functions are outside melos).

### M0.5 — CI: firebase deploys + existing workflow fixes

**Goal:** Rules/indexes/functions deploy from CI with the service account;
the two existing workflows stop drifting.

**Track B** — deploys need real projects. While deferred, land the
PR-side functions build/test job early via M9.1 instead (and the two
workflow fixes below can ride any Track A CI change).

**Context (bugs to fix while here).** *(Both fixed — rode with M1.7's CI
change, per the Track B note above.)*
- `.github/workflows/deploy_apps.yaml` calls `melos run analyze` — that
  script does not exist in `melos.yaml` (it's `lint`).
- `ci.yaml` triggers on `master`; `deploy_apps.yaml` on `main`. The repo's
  default branch is `master` — unify on it.

**Steps**
1. New workflow `firebase_deploy.yaml`: on push to `master` touching
   `apps/duet/{firestore.rules,firestore.indexes.json,storage.rules,functions/**}`
   → `firebase deploy --only firestore:rules,firestore:indexes,storage,functions
   --project duet-staging` using `FIREBASE_SERVICE_ACCOUNT`; prod deploys
   gated on tags or manual `workflow_dispatch` with an environment
   approval.
2. PR job: `functions/` lint+build+test (no deploy).
3. Fix `deploy_apps.yaml` (`analyze`→`lint`, branch `main`→`master`); keep
   its mock-signing build matrix as-is (M9.2 upgrades it). (Done with
   M1.7.)
4. Document rollback: `firebase deploy` of the previous git revision of the
   rules files (the runbook task M9.5 links here).

**Done when:** a rules-only change on a branch shows a green PR run and a
staging deploy on merge; both legacy workflows reference real scripts and
the same branch.

---

## M1 — Identity & account lifecycle

Covers plan M1: contract hardening + error taxonomy (M1.1–M1.4), account
deletion (M1.8, M1.9), profile/display-name/discoverable (M1.5, M1.6), and
the exit criteria (M1.7 rules tests in CI, M1.10 lifecycle E2E).

### M1.1 — Auth error taxonomy surfaced through `Result`

**Goal:** Auth failures become typed values instead of `e.toString()`.

**Context.** `AuthRepository`
(`packages/features/feature_auth/lib/src/domain/auth_repository.dart`) has
exactly five members (`user`, `login`, `signInWithGoogle`,
`signInWithApple`, `logout`); methods throw raw exceptions and `AuthBloc`
catches `on Object` → `AuthState.failure(e.toString())` (auth_bloc.dart
~L61–88). `feature_auth` does **not** depend on `core_utils` yet. Blast
radius: `FirebaseAuthRepository` (same package), Duet's
`MockAuthRepository` (`apps/duet/lib/data/mock_auth_repository.dart`),
app_template/showcase mocks, and all `feature_auth` tests.

**Steps**
1. Add `core_utils` to `feature_auth`'s dependencies.
2. Define `AuthFailure` (sealed class or enum + message) in
   `feature_auth/lib/src/domain/`: `invalidCredentials`, `emailInUse`,
   `weakPassword`, `invalidEmail`, `userDisabled`,
   `requiresRecentLogin`, `network`, `cancelled`, `unknown(raw)`.
3. Convert the contract's methods to `Future<Result<void>>`; map
   `FirebaseAuthException.code` → taxonomy in `FirebaseAuthRepository`
   (one private mapper, unit-tested per code).
4. `AuthBloc` folds `ResultFailure` into `AuthState.failure` carrying the
   typed failure; `LoginScreen`/`SignInView` renders a human message per
   failure kind (message mapping lives UI-side; `cancelled` maps to no
   message at all). Sign-in flows only: logout stays fire-and-forget in
   the bloc — a failure status while still authenticated would fight the
   routers' auth redirects, and Settings surfaces sign-out failures when
   it gains the row (M1.5).
5. Update every implementation and test double
   (`MockAuthRepository`s, `FakeAuthRepository`, `ThrowingAuthRepository`
   — now `FailingAuthRepository`, returning failures instead of throwing)
   and the consuming apps' compilations.

**Done when:** wrong-password on the emulator shows "Email or password is
incorrect" (not a Firebase code dump); all `feature_auth` + app tests
green; no `e.toString()` left in `auth_bloc.dart` (G1, G4).

### M1.2 — Email/password sign-up

**Goal:** New users can create an account in-app.

**Steps**
1. Contract: `Future<Result<void>> signUp(String email, String password,
   {String? displayName})` on `AuthRepository`; implement via
   `createUserWithEmailAndPassword` (+ `updateDisplayName` when provided)
   in `FirebaseAuthRepository`; mirror in mocks. The `account` stream
   moved from `authStateChanges` to `userChanges` so the just-set display
   name (and M1.5's edits) actually reach account listeners — the uid
   `user` stream stays on `authStateChanges`.
2. Bloc: `AuthSignUpRequested` event + handling (reuses M1.1 taxonomy —
   `emailInUse`, `weakPassword` are the key paths).
3. UI: extend `core_ui`'s `SignInView` with a mode toggle or a sibling
   `SignUpView` (keep the design-system pattern: it's a presentation
   widget; `feature_auth` adds a `SignUpScreen` or a mode on
   `LoginScreen`). Add "Create account" affordance to the login screen.
   (Built as a sibling `SignUpView` + an in-place mode toggle on
   `LoginScreen`, so no app router changes were needed.)
4. On success: signed in + the `usersByEmail` upsert listener
   (`apps/duet/lib/injection.dart` ~L114–127) publishes the directory
   entry automatically — assert this in the E2E later (M1.10).
5. Tests: bloc tests for success/failure paths; widget test for the new
   screen; goldens if `core_ui` gained a widget.

**Done when:** emulator sign-up → lands on `/home`; duplicate email shows
the typed error; gate green.

### M1.3 — Password reset + email verification

**Goal:** Users can recover access and verify their address.

**Steps**
1. Contract: `Future<Result<void>> sendPasswordReset(String email)`;
   `Future<Result<void>> sendEmailVerification()`;
   `Stream<bool> get emailVerified` (or expose it on `AuthAccount` —
   prefer adding a `bool emailVerified` field to `AuthAccount`
   [`feature_auth/lib/src/domain/auth_account.dart`] so the existing
   `account` stream carries it; remember `AuthAccount` is `Equatable` —
   update `props`). (Built with the `AuthAccount` field;
   `AuthAccountProvider` gained `refreshAccount()` as the
   reload-on-resume seam the banner calls.)
2. Implement in `FirebaseAuthRepository` (`sendPasswordResetEmail`,
   `currentUser.sendEmailVerification`, `reload()` on resume to refresh
   `emailVerified`); mirror in mocks (instant-verify).
3. UI: "Forgot password?" link on the login screen → email entry →
   confirmation snackbar; a dismissible "Verify your email" banner on
   `/home` while unverified with a resend action. Do **not** hard-gate the
   app on verification in 1.0 (decision recorded here; rules never depend
   on it). (Reset rides the bloc — `AuthPasswordResetRequested` +
   `AuthState.passwordResetSentTo` one-shot marker; the banner is
   `EmailVerificationBanner` in `feature_auth`, wired by Duet's home via
   `Result`-returning callbacks, refreshing on app resume.)
4. Tests: bloc + widget; emulator behavior (reset emails are retrievable
   via the Auth emulator REST API — cover in M1.10).

**Done when:** both flows work on the emulator; unverified banner renders
and dismisses; gate green.

### M1.4 — Re-authentication for sensitive operations

**Goal:** A fresh credential can be demanded before deletion/email change.

**Steps**
1. Contract: `Future<Result<void>> reauthenticate({String? password})` —
   password path uses `EmailAuthProvider.credential`; Google/Apple paths
   re-run the provider flow (`reauthenticateWithProvider` /
   `reauthenticateWithPopup` on web — follow the existing
   platform split in `FirebaseAuthRepository._signInWithProvider`).
2. Map `requires-recent-login` → `AuthFailure.requiresRecentLogin` so
   callers know to trigger this flow reactively, not preemptively.
3. Reusable UI: a `ReauthDialog` in `feature_auth` (password field or
   provider button matched to the account's provider). (Built as
   `showReauthDialog(context, provider:, reauthenticate:)` resolving to
   a bool; `AuthAccount` gained an `AuthProviderKind provider` field —
   password preferred when several are linked — so consumers can match
   the dialog to the account without probing Firebase directly.)
4. Mocks: configurable success/failure. (The feature_auth test doubles
   `FakeAuthRepository`/`FailingAuthRepository` are the configurable
   pair; app mocks succeed.)

**Done when:** unit tests cover password + provider paths; the dialog has
a widget test; M1.9 can consume it; gate green.

### M1.5 — Profile section in Settings: display name + sign-out

**Goal:** Users can edit their display name (propagating to the
directory) and sign out — neither exists in any Duet UI today.

**Context.** Settings = `DuetSettingsPage`
(`apps/duet/lib/ui/settings_page.dart`) wrapping `feature_settings`'
`SettingsScreen`, which renders exactly one push toggle plus a single
`extraTile` slot (currently "Manage plan"). Display-name propagation
already works via the auth `account` stream → upsert listener
(injection.dart ~L114–127) → `FirestoreUserDirectory.upsertSelf`; nothing
calls `updateDisplayName` anywhere.

**Steps**
1. `feature_settings`: widen `SettingsScreen`'s `extraTile` to
   `List<Widget> extraTiles` (or a sections API) — update `showcase`/other
   callers. (Done as `extraTiles` with a `const []` default; only Duet
   passed a tile. While in this file, "Manage plan" moved to a `/paywall`
   route per G8, and the account→directory upsert listener in
   `injection.dart` was hoisted out of the Firebase branch so the mock
   flow publishes through the same seam — which is what makes the
   in-memory re-publish test in step 4 possible.)
2. Contract: `Future<Result<void>> updateDisplayName(String name)` on
   `AuthRepository` (implemented with `updateDisplayName` + `reload`, then
   re-emit on the `account` stream so `CurrentUserName` and the upsert
   listener fire); mirror in mocks.
3. Duet Settings: "Profile" group — display name row (edit dialog with
   validation ≤ 50 chars), account email (read-only), and a "Sign out"
   row (`AuthRepository.logout` → router lands on `/` via the existing
   auth redirect in `apps/duet/lib/app.dart` `_redirect`).
4. Tests: `duet_settings_page_test.dart` grows profile + sign-out
   coverage; bloc-level test that a name edit re-publishes the directory
   entry (in-memory directory).

**Done when:** editing the name updates `usersByEmail.displayName` on the
emulator (verify via the E2E in M1.10); sign-out returns to login; gate +
settings goldens green.

### M1.6 — `discoverable` toggle (and stop clobbering it)

**Goal:** A Settings switch controls whether others can find you by email
— and background upserts stop resetting it to `true`.

**Context (bug to fix).** `DirectoryUser.discoverable` defaults `true` and
the injection upsert listener constructs `DirectoryUser` **without**
passing it — every sign-in force-writes `discoverable: true`
(`FirestoreUserDirectory.upsertSelf` does a full `set`, not a merge).
Rules already support the flag (`firestore.rules` ~L34–44). No UI exists.

**Steps**
1. Persist the user's choice locally (`LocalSettingsRepository` /
   `local_storage`, key e.g. `settings.discoverable`) **and** in the
   directory doc; treat local as the write-through source when composing
   upserts. (Built as a Duet-local `DirectoryPublisher` over
   `local_storage` — Duet-specific privacy state doesn't belong in the
   generic `feature_settings` slice.)
2. Fix the listener: thread the stored preference into the
   `DirectoryUser(discoverable: …)` it writes (default `true` only when
   the user never chose). (The raw injection listener was replaced by
   `DirectoryPublisher`, which centralizes entry composition for both
   the account stream and the Settings toggle.)
3. Settings UI: "Privacy" group — "Discoverable by email" switch with a
   one-line explanation (copy: invites to your email only work when on).
4. `UserDirectory` contract stays as-is (`upsertSelf` already carries the
   flag).
5. Tests: unit test proving a `false` choice survives a fresh sign-in
   upsert (in-memory + `fake_cloud_firestore` variants); widget test for
   the switch.

**Done when:** toggling off → `lookupByEmail` returns `Success(null)` for
another emulator account (extend the E2E in M1.10); the clobber bug has a
regression test; gate green.

### M1.7 — Rules-test harness (net-new) + coverage of today's rules

**Goal:** `firestore.rules` gets executable tests in CI — it has zero
coverage today (`fake_cloud_firestore` does not evaluate rules).

**Steps**
1. New npm workspace `apps/duet/firestore_tests/` (kept out of melos):
   `@firebase/rules-unit-testing` + vitest, `npm test` runs
   `firebase emulators:exec --only firestore 'vitest run'`.
2. Cover the **current** rules file:
   - `usersByEmail`: owner create/update/delete; `get` allowed only when
     `discoverable == true` or self; `list` always denied; stranger writes
     denied. (Writing this coverage found a live hole: `create, update`
     shared one rule checking only `request.resource.data.uid`, so a
     signed-in stranger could overwrite an existing mapping with their own
     uid — an invite hijack. Fixed in the same PR by splitting the rules
     so update also requires owning the existing doc, pinned by a
     regression test.)
   - `deviceTokens/{uid}`: self read/write only.
   - `userInbox/{uid}/messages`: recipient read/update; `create` with
     matching `toUid` (v1 behavior — M2.4 will change this and this test);
     `delete` always denied.
   - deny-by-default catch-all.
3. CI (`ci.yaml`): new job `rules-tests` (node + firebase-tools cache) —
   required on PRs touching `apps/duet/firestore.rules` or the harness;
   cheap enough to run always. (Landed node-only — no Flutter setup —
   running unconditionally; `melos run rules-test` is the root-level
   entry point. M0.5's two legacy-workflow fixes rode along:
   `deploy_apps.yaml` now triggers on `master` and calls
   `melos run lint`.)
4. README in the harness dir: how to run locally, how M2.3 extends it.

**Done when:** the job is green in CI and fails when a rule is
deliberately broken (prove once in the PR description); **M1 exit
criterion** "usersByEmail rules tests in CI" met.

### M1.8 — Account deletion: purge Function v1

**Goal:** A server-authoritative purge deletes everything a uid owns that
exists **today** (directory entry, device tokens, inbox), then the Auth
user — clients cannot delete cross-user data (plan M1).

**Context.** No deletion/purge code exists anywhere. Note: Cloud Functions
v2 has no Auth `onDelete` trigger — use a **callable** that performs the
purge and then deletes the Auth user server-side (also gives synchronous
UX + a clean re-auth check).

**Steps**
1. `functions/src/deleteAccount.ts` — callable, requires App Check (when
   enforced later) and a **recent** ID token (`auth_time` within ~5 min;
   client re-authenticates first via M1.4). (App Check is a
   `TODO(M0.3): enforceAppCheck` comment until M0.3 ships.)
2. Purge in order (idempotent, batched):
   `usersByEmail` docs `where uid == caller` (the doc id is the email
   key, so query by field — never assume the caller's current email),
   `deviceTokens/{uid}`, recursive-delete `userInbox/{uid}`. Leave a
   `// M3.8 extends: pieces, layers, notes, storage` marker.
   (Batching is a `BulkWriter` — no 500-op batch ceiling; the inbox count
   for the summary comes from a `count()` aggregate before the recursive
   delete. Admin SDK handles live in `src/firebase.ts` as lazy singletons
   so import stays side-effect-free.)
3. Finish with `admin.auth().deleteUser(uid)`; return a summary payload.
   (`auth/user-not-found` is swallowed so a retry after a partial run
   completes instead of failing.)
4. Emulator tests in the functions workspace: seeds data for two users,
   calls the function, asserts only the caller's data vanished.
   (Also covers: the stale-sign-in gate firing *before* any purge, and a
   full idempotent re-run returning zero counts. `npm test` now wraps
   vitest in `firebase emulators:exec --only auth,firestore` —
   `firebase-tools` joined the workspace's devDependencies, and
   `test:against-running` mirrors `firestore_tests`' convention.)
5. Log a structured audit line (uid, counts) — Cloud Logging is the
   record; no PII beyond uid.

**Done when:** functions tests green; manual emulator run leaves the other
seeded account untouched; deploy target from M0.5 picks it up. (First two
verified — see PR; the barrel export means M0.5's future deploy target
picks the function up with no further wiring.)

### M1.9 — Account deletion: client flow in Settings

**Goal:** The App-Store-mandated in-app deletion, wired end to end.

**Steps**
1. Add `legal_compliance` to `apps/duet/pubspec.yaml`; use its
   `DeleteAccountButton` + `showDeleteAccountDialog` (confirm-then-callback
   — the package contains no logic, by design) in a "Danger zone" Settings
   group (M1.5's sections).
2. Flow: confirm dialog → re-auth (M1.4 `ReauthDialog`) → call the M1.8
   callable (`cloud_functions` dep, flavor-aware instance) → on success,
   local sign-out + wipe local caches (`LocalStorageService` keys:
   `pieces.records`, `pieces.annotations.*`, `pairing.invites`,
   `review_sync.last_applied.*`, settings keys) → land on login.
   (Re-auth is collected **up front**, not just reactively: the M1.8
   callable rejects any sign-in older than 5 min, so a fresh credential is
   always needed. Local wipe uses `LocalStorageService.clear()` — the whole
   store is account-scoped, so a blanket clear is both simpler and safer
   than key-by-key, and it can't drift as new keys are added.)
3. Failure paths per G4: `requiresRecentLogin` → re-run re-auth; network →
   retry snackbar; never leave a half-signed-out state. (Local wipe +
   sign-out happen only *after* a `Success`, so any purge failure leaves
   the session fully intact — pinned by a test. The retry loop re-opens
   re-auth on `requiresRecentLogin` and gives up cleanly if the user backs
   out.)
4. Mock path: `MockAuthRepository` + an injectable `AccountPurge` seam so
   the headless flow test can drive the UI without functions (G2). (Seam
   is `data/account_purge.dart`; `CallableAccountPurge`
   (`data/callable_account_purge.dart`) wraps the callable under
   `useFirebase: true` and maps `FirebaseFunctionsException` codes onto
   the `AuthFailure` taxonomy — `failed-precondition`/`unauthenticated` →
   `requiresRecentLogin`. `main_emulator.dart` points the region-pinned
   Functions instance at the emulator.)
5. Tests: widget test of the full dialog→reauth→purge-called sequence with
   fakes; `duet_flow_test.dart`-style coverage if cheap. (Six danger-zone
   widget tests: happy path with storage-wipe + sign-out, stale-login
   re-auth-and-retry, network failure leaving the session intact, and the
   two back-out paths; plus a `mapCallableError` code-table unit test and
   an injection assertion that the default branch binds `MockAccountPurge`.
   The full emulator lifecycle proof is M1.10's `auth_lifecycle_test`.)

**Done when:** on the emulator, deleting account removes auth user +
directory entry + tokens + inbox and lands on login; App Review checklist
item "account deletion" satisfiable in-app (M9.4 references this). (Client
flow + all failure paths covered headlessly; the end-to-end emulator
removal is exactly what M1.10 automates — the M1.8 manual proof already
showed the server side purges correctly.)

### M1.10 — Auth lifecycle emulator E2E

**Goal:** One E2E proves the whole lifecycle against the emulator — the M1
exit criterion, extending `collaborator_flow_test`.

**Context.** `apps/duet/integration_test/collaborator_flow_test.dart`
boots Firebase inline (demo options → `useAuthEmulator(9099)` /
`useFirestoreEmulator(8080)` → `configureDependencies(useFirebase: true)`)
and creates users via `FirebaseAuth.instance.createUserWithEmailAndPassword`
directly. Keep that harness pattern.

**Steps**
1. New `integration_test/auth_lifecycle_test.dart`: sign-up (via the repo,
   not raw SDK) → directory entry appears with display name → edit display
   name → directory updates → toggle discoverable off → second account's
   `lookupByEmail` gets `Success(null)` → password reset issued (fetch the
   reset link via the Auth emulator REST `oobCodes` endpoint and assert it
   exists) → email verification issued → re-auth → delete account →
   sign-in now fails, directory/tokens/inbox gone.
2. Requires the functions emulator (M1.8) — extend `dev.sh` usage docs and
   the `duet-emulator` skill's E2E recipe accordingly.
3. Tag/locate it so it runs under `melos run e2e` only (G2).

**Done when:** test passes locally per the skill recipe; wired into the CI
emulator job when M4.5/M9.1 land (do not block M1 on CI plumbing).

**Landed.** `integration_test/auth_lifecycle_test.dart` covers the full
sequence against the live Auth + Firestore + **Functions** emulators
(deletion verified via the admin REST surface: directory-by-uid, device
tokens, and inbox all gone; sign-in then fails). It lives in
`integration_test/` (outside the `test/`-only headless gate), so `melos
run test` skips it and `melos run e2e` runs it — no tag needed. `dev.sh`
+ the `duet-emulator` skill now name both e2e suites and the Functions
requirement.

*Bug this E2E surfaced (fixed in the same PR).* Writing the
discoverable-off step showed `FirestoreUserDirectory.lookupByEmail`
leaked a hidden entry as a **failure**, not `Success(null)`: with the
real rules a stranger's exact-key GET of a non-discoverable doc is
*denied* (proven: emulator returns 403), and `Result.guard` surfaced the
`permission-denied` as `ResultFailure`. That breaks the design invariant
(a hidden entry must be indistinguishable from an absent one — the rules'
own words) and the invite-by-email UX (a hidden user would show an error,
not "no account found"). Fixed by mapping `permission-denied` → `null` in
`lookupByEmail`, matching `InMemoryUserDirectory`; covered headlessly via
`mock_exceptions`' GET interception (`fake_cloud_firestore` evaluates no
rules, so only the emulator — or an injected throw — reaches this path).

**M1 exit criteria met:** auth error taxonomy (M1.1), full account
lifecycle incl. deletion (M1.8/M1.9), and this emulator E2E — the
"usersByEmail rules tests in CI" criterion landed with M1.7.

---

## M2 — Cloud schema + security rules for pieces

Covers plan M2 fully: schema (M2.1), rules + storage rules + indexes
(M2.2), rules-suite-in-CI exit (M2.3), and closing both documented v1
risks (M2.4 inbox, M2.5 directory). M2.4 also pulls invite *acceptance*
server-side — sequencing demands it (see task).

### M2.1 — Cloud schema design doc

**Goal:** One committed document that every M3–M5 task implements against.
*Design before code.*

**Steps**
1. Write `docs/duet_cloud_schema.md` covering:
   - `/pieces/{pieceId}`: `title`, `ownerId`, `ownerName`,
     `participantIds: string[]` (owner + collaborators — for
     `array-contains` queries; today this is a *derived getter* on the
     `Piece` entity, it becomes **materialized**), `collaborators:
     [{uid,name,email}]` (embedded array, matches `piece_mappers.dart`),
     `basePdfChecksum` (sha256, computed in
     `LocalPieceRepository._copyIntoPiecesStorage` today),
     `createdAt`/`updatedAt` as **`Timestamp`** (local mappers use
     ISO-8601 strings — Firestore mappers convert).
   - `/pieces/{id}/layers/{uid}`: one doc per author (`role`, `strokes[]`
     as in `annotation_mappers.dart`, `updatedAt`, monotonically
     increasing `rev`). Maps to the reader's `ParticipantLayer`
     projection; conflict-free because each participant writes only their
     own doc (plan architecture decision 1).
   - `/pieces/{id}/notes/{noteId}`: `AudioNote` fields + `deletedAt:
     Timestamp?` tombstone (M4.4 uses it — schema it now).
   - `/pieces/{id}/reads/{uid}`: `{lastOpenedAt: Timestamp}` — the
     per-user watermark for unread dots (M3.7) and reader attention
     markers (M4.3). The library's `LibraryState.isUnread` doc comment
     explicitly calls for this store.
   - Storage: `/pieces/{id}/base.pdf` (custom metadata: `checksum`),
     `/pieces/{id}/audio/{assetId}`. Record the dedupe decision: per-piece
     objects; the checksum keys the **local cache** and suppresses
     re-upload of an identical PDF for the *same* piece — no cross-piece
     global object (Open decisions).
   - `/inviteTokens/{token}` (M5.2): `pieceId`, `ownerId`, `ownerName`,
     `createdAt`, `expiresAt`, `consumed`, `consumedBy` — mirrors
     `_StoredInvite` in
     `feature_pairing/lib/src/data/deep_link_invite_service.dart`.
   - `/entitlements/{uid}` (M6.3): `pro: bool`, `updatedAt`, source.
2. Resolve the naming mismatch explicitly: the commented-out sketch in
   `apps/duet/firestore.rules` (~L63–76) uses `teacherId`/
   `collaboratorIds`; the real model is `ownerId` + `participantIds`.
   The doc supersedes the sketch.
3. Write down the region (M0.H), offline-persistence stance (mobile
   default-on; web not required for 1.0), and index needs
   (`participantIds` array-contains + `updatedAt` desc composite).
4. State the ACL matrix (who may create/read/update/delete each doc) —
   M2.2 translates it 1:1; client mutations that rules can't express
   (collaborator add/leave, inbox sends) are named as Functions (G7).

**Done when:** doc merged; M2.2/M3.x reference sections of it rather than
re-deciding; no code changes in this task.

**Landed.** `docs/duet_cloud_schema.md` — every field grounded in the
current code (`Piece`/`piece_mappers`, `InkLayer`/`AudioNote`/
`annotation_mappers`, `PdfRenderService.checksum` = sha256 hex,
`_StoredInvite`, `LibraryState.isUnread`, `MonetizationService`'s `pro`
entitlement). Covers all six collections + the three live M1 ones, the
Storage layout + per-piece dedupe decision, region/offline/index stances,
and the full ACL matrix with the six Function-only mutations named (G7).
Records the three cloud-only deltas from the local model explicitly:
`participantIds` derived-getter → **materialized** field, `layers`
bundled blob → **per-author docs** (+ `updatedAt`/`rev`), and `notes`
gain a `deletedAt` tombstone; plus the ISO-8601-string → `Timestamp`
boundary conversion. Supersedes the `teacherId`/`collaboratorIds` sketch
in `firestore.rules`. No code changed.

### M2.2 — `firestore.rules` + `storage.rules` + `firestore.indexes.json`

**Goal:** Enforceable rules for the pieces schema, mirroring the ownership
guards the local repositories enforce client-side today.

**Context.** The guards to mirror (from
`packages/core/pieces/lib/src/data/`): owner-only `deletePiece` /
`removeCollaborator` (`local_piece_repository.dart` throws
`OwnershipViolation`), author-only stroke/note mutation
(`local_annotation_repository.dart` — "cannot add a stroke authored by
another participant", "not the note author").

**Steps**
1. Replace the commented sketch in `apps/duet/firestore.rules` with:
   - `pieces/{id}`: `read` if `request.auth.uid in
     resource.data.participantIds`; `create` if caller is `ownerId` and is
     in `participantIds`; `update` by owner for metadata (title/ownerName)
     — **collaborator-set changes denied to clients** (Functions only,
     M2.4); `delete` owner-only.
   - `layers/{uid}`: participant read; write only if `request.auth.uid ==
     uid` and caller is a participant of the parent (use `get()` on the
     piece doc); owner may `delete` any layer (collaborator-removal
     cascade).
   - `notes/{noteId}`: participant read; create/update/delete only when
     `authorId == request.auth.uid` (update restricted to tombstoning:
     only `deletedAt` may change).
   - `reads/{uid}`: self read/write, participant-gated.
2. `storage.rules`: membership mirrored via **cross-service rules** —
   `firestore.get(/databases/(default)/documents/pieces/$(pieceId))
   .data.participantIds` gates read/write of `/pieces/{pieceId}/**`;
   write of `base.pdf` owner-only; audio writes participant-scoped; cap
   object sizes (PDF ≤ 50 MB, audio ≤ 5 MB — align M8.3).
3. `firestore.indexes.json`: composite `pieces(participantIds
   array-contains, updatedAt desc)`; add any needed for `notes`
   (`deletedAt` filters) as identified.
4. Keep the two v1-risk comment blocks in the rules file updated: M2.4 and
   M2.5 delete them as the risks close — this task only annotates that the
   closure tasks exist.

**Done when:** rules compile in the emulator; M2.3's suite (developed in
lockstep or immediately after) proves the matrix; **no client code writes
these collections yet** (M2 exit: rules-tests green *before* client code —
G6).

**Landed.** `firestore.rules` pieces block + `storage.rules` +
`firestore.indexes.json`, translating `docs/duet_cloud_schema.md`'s ACL
matrix 1:1. `pieces`: participant read, owner-only create asserting the
sole-participant/no-collaborator invariant, owner metadata update with
`ownerId`/`participantIds`/`collaborators` **immutable to clients** (the
Function bypasses via Admin SDK — M2.4), owner delete. `layers/{uid}`:
participant read, author-only write, author-or-owner delete (removal
cascade). `notes/{noteId}`: participant read, author create, author
`deletedAt`-only tombstone update (`diff().affectedKeys().hasOnly`),
no hard delete. `reads/{uid}`: self-only, participant-gated.
`storage.rules`: cross-service `firestore.get(...).participantIds` gating,
`base.pdf` owner-write ≤ 50 MB, `audio/{assetId}` participant-write
≤ 5 MB. Index: `pieces(participantIds array-contains, updatedAt desc)`;
notes/`deletedAt` indexes deferred until M4.4's query lands (no
speculative index). `inviteTokens`/`entitlements` stay denied-by-default
until M5.2/M6.3. Verified against the emulator: rules **compile**, M1.7
suite **20/20** (no regression to `usersByEmail`/`deviceTokens`/
`userInbox`), and a throwaway pieces smoke probe (6/6) exercised the
subtle `get()`-based gating, the create invariant, collaborator-set
immutability, author-only note create, and the tombstone-only update.
The committed matrix is M2.3. The two v1-risk comment blocks now name
their closure tasks (M2.4 inbox, M2.5 directory).

### M2.3 — Rules tests: pieces/layers/notes/reads + Storage

**Goal:** The M2 exit — the emulator rules suite covering the pieces
schema, green in CI.

**Steps**
1. Extend `apps/duet/firestore_tests/` (M1.7): fixtures for owner,
   collaborator, stranger; full matrix per collection
   (create/read/update/delete × role), including: collaborator cannot
   touch another's layer doc; note tombstone update allowed only for
   `deletedAt`; client cannot mutate `participantIds`; stranger sees
   nothing.
2. Storage rules tests (`initializeTestEnvironment` supports storage):
   participant can read `base.pdf`, stranger cannot; non-owner cannot
   overwrite `base.pdf`; size-cap rejections.
3. Wire into the M1.7 CI job (same emulator boot).

**Done when:** suite green in CI; a deliberate rule regression fails it;
plan M2 exit satisfied.

**Landed.** Two sibling files in `apps/duet/firestore_tests/test/`:
`pieces_rules.test.ts` (21 tests — the full CRUD × role matrix for
`pieces`/`layers`/`notes`/`reads` with owner/collaborator/stranger/anon
fixtures: participant gating, the sole-participant create invariant,
collaborator-set + `ownerId` immutability to clients, participant-scoped
vs. unscoped query, author-only layer/note writes, the `deletedAt`-only
note tombstone, no-hard-delete, self-only read watermarks) and
`storage_rules.test.ts` (5 tests — participant read of `base.pdf`,
owner-only base write, participant audio write, the 5 MB cap rejection,
deny-by-default; membership resolved via the cross-service
`firestore.get`, so it seeds the gating piece doc and boots both
emulators). `npm test` now runs `--only firestore,storage`; CI inherits
it (no job change beyond a name/comment refresh). Full suite **46/46**
(20 M1 + 21 pieces + 5 storage). *Break-proof (for the PR):* weakening
`pieces` read from participant-only to any-signed-in failed exactly the
stranger-denied read + unscoped-query tests (`2 failed | 44 passed`).

*One harness fix worth noting:* adding sibling files surfaced a
cross-file race — vitest runs files in parallel workers, and all three
share one emulator + `clearFirestore`/`clearStorage` in `beforeEach`, so
one file's clear wiped another's fixtures mid-test (it failed three M1.7
tests that had always passed alone). Fixed with a `vitest.config.ts`
setting `fileParallelism: false`.

**M2 exit satisfied:** the pieces rules suite is green and required in CI,
ahead of any client code that writes these collections (G6).

### M2.4 — Invite lifecycle server-side (send / accept / leave callables)

**Goal:** Close documented v1 risk #1 (inbox spam) and make invite
*acceptance* authorizable — under M2.2 rules a client can no longer add
itself to someone else's piece, so acceptance must be a Function **before**
M3's cloud pieces land.

**Context.** Today `DefaultCollaboratorInviteService.sendInvite`
(feature_pairing) writes the invitee's inbox directly via
`UserMessageGateway.sendToUser`; `FirestoreUserMessaging.sendToUser`'s doc
comment says production swaps exactly this for a Function. Acceptance
paths converge on `PieceRepository.addCollaborator`/`pairCollaborator`.
The collaborator cap (`CollaboratorLimits`: free = 1, paid = 8,
per-piece) is checked in five client call sites and nowhere on a server.

**Steps**
1. Functions (v2 callables, in `functions/`):
   - `sendInvite({pieceId, inviteeEmail})`: caller must be piece owner
     (piece doc exists → get; pre-M3, when no piece doc exists, validate
     against the caller's own uid only and record the pieceId opaquely —
     keep a `// tighten in M3.6` marker); resolve
     invitee via `usersByEmail` (admin read, respecting `discoverable`);
     enforce the cap server-side (constant mirrored from
     `CollaboratorLimits` with a cross-reference comment; M6.3 upgrades
     the pro lookup); write the `userInbox` message (type `invite`).
   - `acceptInvite({messageId})`: message must exist, be addressed to
     caller, `type == 'invite'`; re-check cap; add caller to
     `pieces/{id}.participantIds` + `collaborators` transactionally
     (post-M3; pre-M3 it only marks the message accepted); mark message
     read/consumed.
   - `leavePiece({pieceId})`: remove caller from participant arrays +
     delete their layer/notes docs (post-M3).
2. Rules: `userInbox` `create: if false` for clients (recipient
   read/update stays); delete the inbox-spam risk comment block; update
   the M1.7 rules tests that asserted client-create.
3. Client swap behind contracts (G3): `DefaultCollaboratorInviteService`
   send/accept call the callables under Firebase
   (`cloud_functions`); the in-memory path
   (`InMemoryUserMessaging` + direct `addCollaborator`) stays for the
   headless gate (G2). `apps/duet/lib/injection.dart` picks per
   `useFirebase`.
4. Update `dev.sh` seeding + the collaborator E2E: the existing
   `collaborator_flow_test.dart` asserts a client-written inbox doc —
   rewrite the send/accept steps through the service (now callable-backed)
   with the functions emulator up.
5. Functions unit/emulator tests: spam attempt from non-owner rejected;
   cap enforced at cap; happy path end-to-end.

**Done when:** rules tests show clients cannot create inbox docs;
emulator E2E passes through the callables; v1 risk #1 comment removed;
plan M2 "inbox create moves behind a Function" + M5's "M2 inbox-write
authorization" both satisfied.

**Landed.** Three v2 callables in `functions/src/`: `sendInvite`
(auth-gated; resolves the invitee via `usersByEmail` admin read respecting
`discoverable`, exactly like the client directory; owner name from the
caller's token; writes the recipient inbox with the Admin SDK; returns the
resolved recipient), `acceptInvite` (verifies the message is addressed to
the caller, is an `invite`, and is unread, then marks it consumed), and
`leavePiece` (doc-guarded — a no-op pre-M3, the participant-array removal
+ layer delete ready for M3). Cap constant mirrored in
`collaboratorLimits.ts` with a cross-ref; owner-ownership and the real cap
count carry `// M3.6` markers (both need the piece doc M3 lands).

Rules: `userInbox` `create: if false` (recipient read/update stays); the
v1 inbox-spam risk block is gone. `firestore_rules.test.ts`'s
client-create test is flipped to assert **denial** (both a stranger and
the recipient) — 45/45. Client swap (G3): `CallableCollaboratorInviteService`
(`apps/duet/lib/data/`) decorates the default service — preview, inbox
stream, and the pre-M3 on-device accept mutation stay local; send + accept
route through the callables; `injection.dart` picks per `useFirebase`, the
headless in-memory path unchanged (G2, injection guardrail green).

Functions tests (`invite_lifecycle.test.ts`, emulator-backed, 8):
unauthenticated + missing-arg rejections, discoverable-invitee resolve +
inbox write, non-discoverable/absent → `no-account` (no write), accept
marks read, wrong-caller/`not-found` + already-consumed rejections, and
the pre-M3 `leavePiece` no-op. The collaborator E2E is rewritten through
the callable path (Functions emulator wired; the owner-side raw inbox read
— which the recipient-only rule now denies — replaced by the `sendInvite`
resolved outcome + the collaborator's own `watchInvites`). A vitest
`fileParallelism: false` config was added to the functions workspace (the
new file's `beforeEach` clear raced the `deleteAccount` suite, same as
M2.3). *Manual proof (PR):* driving the deployed callables over HTTP —
`sendInvite` → inbox written → a client's direct inbox write **403** →
`acceptInvite` → message consumed.

### M2.5 — Directory lookup hardening (App Check + rate limiting)

**Goal:** Close documented v1 risk #2 — un-rate-limited `usersByEmail`
lookups.

**Steps**
1. Callable `lookupEmail({email})`: admin-side exact-key get honoring
   `discoverable` (identical semantics to
   `FirestoreUserDirectory.lookupByEmail` — `Success(null)` for absent
   *and* non-discoverable); per-caller rate limit (e.g. 20/min via a
   `rateLimits/{uid}` doc with windowed counters, or the
   firebase-functions rate-limiter pattern — document the choice).
2. Prepare App Check enforcement on the callable via an env-driven
   `enforceAppCheck` flag, **off on the emulator** so Track A tests run.
   **[Track B]** turn it on and flip console **enforcement** for
   Firestore/Functions in staging first, then prod (**[HUMAN]** console
   toggles; M0.3 set up monitoring).
3. Client: `FirestoreUserDirectory.lookupByEmail` → callable under
   Firebase; direct-Firestore read path removed; rules for `usersByEmail
   get` can then drop to self-only (update rules + M1.7 tests; delete the
   risk comment block).
4. Keep `upsertSelf` as a direct client write (self-doc, already safe).
5. Tests: functions test for rate-limit trip; E2E lookup path still green.

**Done when:** stranger enumeration/brute-force is bounded by the rate
limit; both v1-risk comment blocks in `firestore.rules` are gone; plan M2
risk-closure bullet done except the App Check enforcement flip, which
completes in Track B.

**Landed (Track A).** `functions/src/lookupEmail.ts` — a rate-limited
callable with the same semantics as `FirestoreUserDirectory.lookupByEmail`
(exact-key get honoring `discoverable`; `null` for absent *and*
non-discoverable alike). Per-caller limit: 20/min via a `rateLimits/{uid}`
fixed-window counter mutated in a transaction (server-only collection —
deny-by-default). Rules: `usersByEmail get` dropped to **self-only**, so a
client can no longer read (or brute-force) another user's entry — both
"accepted risk" comment blocks are gone (only past-tense "closed"
notes remain). Client swap (G3): `CallableUserDirectory`
(`apps/duet/lib/data/`) routes `lookupByEmail` through the callable and
keeps `upsertSelf` a direct self-doc write; `injection.dart` wraps the
Firestore directory under `useFirebase` (headless in-memory path
unchanged, G2). The `usersByEmail` rules tests are updated (stranger get —
discoverable or not — now denied); rules 44/44, functions 21/21 (incl. the
rate-limit trip, per-uid isolation, and window reset), duet 50/50.
*Manual proof (PR):* the deployed callable resolves a discoverable account,
returns `null` for a hidden one, and a client's direct cross-user
`usersByEmail` get is **403**.

**App Check enforcement flag** is wired env-driven (`ENFORCE_APP_CHECK`,
**off** on the emulator). Turning it on + flipping console enforcement for
Firestore/Functions (staging → prod) is the **▸B / [HUMAN]** remainder
(needs M0.3 monitoring) — the one live step the `▸B` marker denotes.

---

## M3 — Cloud-backed pieces (the big migration)

Covers plan M3: the three cloud implementations (M3.1, M3.2, M3.5), upload
progress + dedupe (M3.3), offline binary cache (M3.4), one-time migration
+ DI flip (M3.6), live gallery + real unread signal (M3.7), and the
emulator-E2E exit + deletion cascade (M3.8). Architecture decisions 1–2
(Firestore + Storage as truth, offline-first, local repos become the
cache) are implemented here.

### M3.1 — `FirestorePieceRepository`

**Goal:** `PieceRepository` implemented on `/pieces` per the M2.1 schema —
metadata only (binaries are M3.3/M3.4).

**Context.** The contract
(`packages/core/pieces/lib/src/domain/piece_repository.dart`) has 9
methods; blocs (`LibraryBloc`, `PieceDetailCubit`, `ScoreBloc`) must not
change (G3). `pieceToJson`/`pieceFromJson`
(`piece_mappers.dart`) are the shape reference but Firestore docs use
`Timestamp` + materialized `participantIds`. The best in-repo template is
`feature_grocery_list`'s `FirestoreGroceryRepository` (snapshots streams,
transactions, batch, subcollections). Decide placement: new
`lib/src/data/firestore_piece_repository.dart` in `packages/core/pieces`
**adds a `cloud_firestore` dependency to that package** — acceptable
(precedent: `user_directory` does the same); keep entities/mappers
Firebase-free.

**Steps**
1. Firestore mappers (`firestore_piece_mappers.dart`): entity ↔ doc map
   with `Timestamp` conversion + `participantIds` materialization; unit
   tests mirroring `piece_mappers_test.dart`.
2. Implement: `watchPieces` = query `participantIds array-contains uid`
   ordered `updatedAt desc` via `snapshots()`; `getPiece`; `importPiece`
   (doc create; binary upload arrives in M3.3 — until then store the
   local path as cache truth); `renamePiece` (owner check + update);
   `deletePiece` (owner-only → doc delete; cascade is M3.8);
   `addCollaborator`/`pairCollaborator` — **not callable by production
   UI** after M2.4 (acceptance goes through the callable); implement them
   for the migration/import paths that legitimately self-mutate, guarded
   to owner-only semantics; `leavePiece` → M2.4 callable under Firebase;
   `registerImportedPiece` for the bundle escape hatch.
3. Map permission-denied errors to `OwnershipViolation` so bloc behavior
   matches the local repo's contract documented in
   `piece_repository.dart` (~L26–35).
4. Enable offline persistence explicitly in the Firebase entry points
   (`FirebaseFirestore.instance.settings = const Settings(persistenceEnabled:
   true)`) — decision recorded in M2.1.
5. Tests: `fake_cloud_firestore` suite mirroring
   `local_piece_repository_test.dart`'s 32 cases (participant scoping,
   sort order, ownership violations, idempotent collaborator add,
   registerImportedPiece duplicate-id failure). Note `fake_cloud_firestore`
   doesn't enforce rules — rules coverage already exists (M2.3).

**Done when:** suite green; no bloc/UI changes needed; not yet wired into
DI (M3.6 flips).

**Landed.** `FirestorePieceRepository` + `firestore_piece_mappers.dart` in
**`apps/duet/lib/data/`** — kept out of `core/pieces` so the domain package
stays Firebase-free (the task offered `core/pieces` per the `user_directory`
precedent, but pieces is Duet-specific and this keeps `cloud_firestore` at
the app layer where backend choice is composed; M3.2's annotation repo
follows the same placement). `watchPieces` =
`participantIds array-contains` + `updatedAt desc` `snapshots()`; mutations
are transactions bumping `updatedAt` and re-materializing `participantIds`
from the entity. **Metadata only:** the base PDF stays device-local
(upload is M3.3/M3.4) — import/register stage it under `pieces/` and record
the path in a `pieces.cloudBasePaths` side-map; reads hydrate `basePdfPath`
from it (empty for a piece synced from another device — M3.4). Ownership
guards mirror the local repo (owner-only delete/removeCollaborator, owner
can't leave), and a rules `permission-denied` maps to `OwnershipViolation`
so blocs behave identically (G3, no bloc/UI change). Production accept/leave
still route through the M2.4 callables (the rules make `participantIds`
immutable to clients); `addCollaborator`/`pairCollaborator`/`leavePiece`
here serve the migration/import paths (M3.6) and tests. Cascade of a
deleted piece's subcollections is the `// M3.8` follow-up. Tests: a
`fake_cloud_firestore` suite (23) mirroring `local_piece_repository_test`
(participant scoping, `updatedAt`-desc sort, ownership violations,
idempotent add, duplicate-id register) + a mappers suite (5); fake enforces
no rules — that coverage is M2.3. **Not wired into DI** — M3.6 flips
`useFirebase` onto it.

### M3.2 — `FirestoreAnnotationRepository`

**Goal:** `AnnotationRepository` on `/pieces/{id}/layers/{uid}` +
`/notes/{noteId}` — per-author layer docs make live sync conflict-free by
construction.

**Steps**
1. Firestore mappers for `InkLayer`/`InkStroke`/`AudioNote`/`Region`
   (reuse shapes from `annotation_mappers.dart`, convert dates).
2. `watch(pieceId)`: combine three snapshot streams (layers collection,
   notes collection, piece doc for participant identity) into
   `PieceAnnotations` — cache latest of each, emit on any change; exclude
   tombstoned notes (M4.4 filters here).
3. Mutations: `addStroke` → transaction on own layer doc (append + bump
   `rev` + `updatedAt`; create doc with role on first stroke — port
   `_roleFor` logic from `local_annotation_repository.dart`);
   `eraseStroke` → own-doc rewrite; `addAudioNote`/`deleteAudioNote` →
   own note docs (delete becomes tombstone in M4.4 — plain delete until
   then); keep the client-side `OwnershipViolation` guards **verbatim**
   (defense in depth; rules are the backstop).
4. Privileged ops: `replaceAuthorSlice` (bundle import escape hatch — own
   slice only under rules; document that importing *another author's*
   bundle slice cloud-side is unsupported and review_sync falls back to
   local-only annotations in that case, or the op is retained for the
   local cache layer only — record the choice in M2.1 doc);
   `removeAuthorSlice` (owner path, used by collaborator removal);
   `clearPiece` (owner path; full cascade in M3.8).
5. `Stream` hygiene: broadcast controllers per pieceId, cancel on last
   listener (match `LocalAnnotationRepository`'s controller discipline).
6. Tests: mirror `local_annotation_repository_test.dart` (per-author
   layers, ownership rejections, watch emissions, slice replace/remove)
   on `fake_cloud_firestore`; plus a two-uid convergence test (writer A's
   stroke shows in B's `watch`).

**Done when:** suite green; `ScoreBloc` tests still pass against the
contract; not yet in DI.

**Landed.** `apps/duet/lib/data/firestore_annotation_repository.dart` +
`firestore_annotation_mappers.dart` (placed in `apps/duet/lib/data/` beside
`FirestorePieceRepository`, per the M3.1 placement decision — the Firebase impls
are Duet-specific and `core/pieces` stays infra-free). `watch` is a hand-rolled
combine-latest over the layers collection, notes collection, and piece document:
each caches its latest snapshot and the first `PieceAnnotations` is withheld
until all three have loaded (so `.first` reflects true state, not an empty
race), then re-emits on any change. Each layer's `PieceRole` is derived from the
piece's `ownerId` (owner vs. collaborator); tombstoned notes (`deletedAt != null`)
are filtered out here (M4.4 flips the tombstone). Mutations: `addStroke` is a
transaction on the caller's own `layers/{uid}` doc (append + bump `rev` +
`updatedAt`; first stroke reads the piece doc in-transaction to resolve the role,
porting `LocalAnnotationRepository._roleFor`); `eraseStroke` locates the stroke
across layers to reproduce the local guards exactly (unknown → `StateError`,
another author's → `OwnershipViolation`) then rewrites the caller's own doc;
`addAudioNote`/`deleteAudioNote` write own note docs (**plain delete** for now —
M4.4 converts it to a `deletedAt` tombstone update). Client-side
`OwnershipViolation` guards are kept **verbatim** as defense in depth (rules are
the backstop; a rules `permission-denied` maps to `OwnershipViolation`). `watch`
uses a broadcast controller whose `onListen`/`onCancel` start and cancel the
Firestore subscriptions (cancel-on-last-listener), matching
`LocalAnnotationRepository`'s controller discipline. **Deviation (recorded in
`docs/duet_cloud_schema.md`, Function-only mutations #7):** the privileged
cross-author ops (`clearPiece`, `removeAuthorSlice`, foreign-author
`replaceAuthorSlice`) run against Firestore here for the fake-backed tests and
the own-author case, but in production are the M3.8 purge Function's job;
`review_sync` importing another author's slice therefore falls back to
local-only annotations. `replaceAuthorSlice` does **not** depend on
`PieceRepository` (unlike the local impl) — the role comes straight from the
piece doc via `_firestore`, one fewer DI edge. Tests:
`firestore_annotation_mappers_test.dart` (7) +
`firestore_annotation_repository_test.dart` (18, mirroring
`local_annotation_repository_test.dart` on `fake_cloud_firestore` plus a two-uid
convergence test — writer A's stroke surfaces in B's `watch`). Full gate green;
not wired into DI (M3.6 flips `useFirebase`).

### M3.3 — PDF upload on import: checksum dedupe + progress UI

**Goal:** Import uploads `base.pdf` to Storage with visible progress;
identical re-imports don't re-upload.

**Context.** Import flow: `ImportPieceBloc`
(`feature_library/lib/src/bloc/import_piece_bloc.dart`) → file pick →
`PdfRenderService.open` validation → `PieceRepository.importPiece`;
checksum today computed inside `LocalPieceRepository._copyIntoPiecesStorage`
via `PdfrxRenderService.checksum` (sha256 of bytes). `ImportPieceState`
has only `isSubmitting` — no progress.

**Steps**
1. New domain seam in `pieces`: `PieceBinaryStore` (or fold into the
   repository — prefer a separate contract so progress is streamable):
   `Stream<UploadProgress> uploadBasePdf(pieceId, localPath, checksum)`;
   Firebase impl on `firebase_storage` (`putFile` with metadata
   `{checksum}`), local no-op impl for the mock path.
2. Dedupe: before upload, `getMetadata()` on the object — matching
   checksum ⇒ skip (piece re-import / `registerImportedPiece` with same
   PDF).
3. `ImportPieceBloc`: `submitting` grows a `progress: double?`;
   `ImportPiecePage` renders a determinate progress bar + cancel;
   failures per G4 (retry keeps the picked file).
4. Import ordering: create piece doc → upload → stamp
   `basePdfUploaded: true` (schema field, add to M2.1 doc) so a killed
   app can resume/repair (M8.4 audits this path).
5. Tests: bloc test with a scripted progress stream; fake store impl.

**Done when:** import on the emulator (storage emulator, M0.4) shows real
progress and lands the object; duplicate import skips the upload
(asserted in a test); gate green.

**Landed.** New seam `PieceBinaryStore` + `UploadProgress` in `core/pieces`
(`piece_binary_store.dart`) with a `NoopPieceBinaryStore` (emits one
`UploadProgress.skipped()` — the local/mock path keeps binaries on-device, so
there's nothing to push; bound by default → G2 stays intact). Firebase impl
`FirebasePieceBinaryStore` in `apps/duet/lib/data/` (per the M3.1 placement
decision): `getMetadata().customMetadata['checksum']` match ⇒ skip;
`putFile` with `{checksum}` metadata, mapping `snapshotEvents` → `UploadProgress`;
on completion stamps `basePdfUploaded: true` on the piece doc (owner update,
allowed by the M2.2 rules) — a resume/repair signal (schema field added to M2.1
doc, import ordering *create → upload → stamp*). Added `firebase_storage
^13.0.0` to duet. `ImportPieceState` grew `progress: double?`; `ImportPieceBloc`
gained the store dep + an upload step after `importPiece` (driven via a managed
subscription, not `await for`, so `ImportCancelled` can abort it — bloc's
default concurrent transformer lets the cancel event run while submit awaits);
a failed/cancelled upload keeps the created piece in an internal field so a
retry re-uploads instead of duplicating (G4: the picked file/title survive).
`ImportPieceScreen` renders a determinate `LinearProgressIndicator` + a Cancel
button while submitting. Threaded `binaryStore` through
`LibraryPage`→`LibraryHomeScreen`→`ImportPiecePage` and every construction site
(`app.dart`, `duet_flow_harness`, the two hand-rolled-DI app tests, the library
widget + golden tests). **Deviations:** (1) the real `FirebasePieceBinaryStore`
is **not** unit-tested — the codebase has no Storage fake (Firestore uses
`fake_cloud_firestore`; Storage is emulator-tested, M2.3), so its dedupe/progress
is emulator-verified and the *contract-level* dedupe (`skipped` ⇒ complete) is
asserted via a fake store in the bloc test. (2) Interactive mid-upload **cancel
is implemented** (not deferred). Tests: `noop_piece_binary_store_test.dart` (4)
+ 11 `ImportPieceBloc` tests (progress sequence, dedupe-skip, create-failure,
upload-failure, retry-without-re-create, cancel). Full gate green (incl. golden);
not wired to the cloud repos yet — M3.6 flips `useFirebase`.

### M3.4 — Binary download/cache manager (offline reading)

**Goal:** Readers open PDFs from a local cache keyed by checksum; a
musician on stage without Wi-Fi still opens her sheets (architecture
decision 2).

**Context.** Today `Piece.basePdfPath` is an on-device absolute path and
the reader opens it directly
(`_ScoreViewerScreenState._maybeOpenPdf`). Under cloud truth, the path
must resolve via cache-or-download.

**Steps**
1. `PdfBinaryCache` in `pieces` (contract + impl): `Future<Result<String>>
   pathFor(Piece piece)` — hit: `{documents}/pieces_cache/{checksum}.pdf`;
   miss: download from Storage with progress, verify sha256 == checksum
   (reuse `PdfRenderService.checksum`), then return. LRU/size policy: keep
   simple total-size cap (e.g. 1 GB) with least-recently-opened eviction.
2. `FirestorePieceRepository` stops persisting device paths;
   `basePdfPath` on the entity becomes the *resolved cache path* filled at
   read time (or introduce `Piece.basePdfSource` — decide in M2.1 doc;
   keep entity churn minimal for the local impl).
3. Reader wiring: `DuetScorePage` resolves via the cache before
   constructing `ScoreViewerScreen`; downloading state renders the
   existing `LoadingView` pattern with progress; failure →
   `ErrorRetryView` (G4).
4. Local repositories become the cache layer, not dead code: point
   `LocalPieceRepository`'s pieces dir usage at the same cache layout
   where practical — do not maintain two blob stores.
5. Tests: cache hit short-circuits network (fake store); checksum
   mismatch → re-download once → hard failure surfaces honestly.

**Done when:** airplane-mode test: piece opened once online opens again
offline on the emulator/device; gate green.

**Landed.** New `PdfBinaryCache` contract + `DefaultPdfBinaryCache` impl in
`core/pieces` (`pathFor(piece)` → **cache hit** (`{documents}/pieces_cache/
{checksum}.pdf`) → **on-device copy** (`basePdfPath`) → **download + sha256-
verify + retry-once**, with a least-recently-opened total-size cap). Downloads
delegate to a **widened** `PieceBinaryStore.downloadBasePdf({pieceId, destPath})`
(M3.3's contract grew the read direction): `NoopPieceBinaryStore` fails it (the
local composition never downloads), `FirebasePieceBinaryStore` does it via
Storage `writeToFile`. `ScoreBloc` gained an **optional** `PdfBinaryCache?` —
`_onOpened` resolves the base PDF to a readable local path and emits
`piece.copyWith(basePdfPath: resolved)` before going `ready` (the existing
loading/failure states cover the wait + a download failure, G4). `Piece.copyWith`
grew a `basePdfPath` param for this. Registered `PdfBinaryCache` in DI (one
backend-agnostic `DefaultPdfBinaryCache` over the branch-selected
`PieceBinaryStore`); `DuetScorePage` passes it to `ScoreBloc`. **Deviations
(recorded in M2.1 doc):** (1) resolve happens in `ScoreBloc` (optional cache;
`null` = today's on-device behaviour → **zero** churn to existing feature_score
tests and every `ScoreViewerScreen` construction site stays untouched) rather
than `DuetScorePage` reaching into the reader — reuses the state machine and
keeps the cache a pieces-domain seam. (2) No new `Piece.basePdfSource` field —
`basePdfPath` is overridden via `copyWith`. (3) Local `pieces/{id}.pdf` →
checksum-keyed-cache unification **deferred to the M3.6 migration** (avoids a
data-location change pre-flip; the local file is returned in place, no second
store). (4) Download-progress UI deferred with it (local resolves instantly; no
visible download until M3.6). (5) `FirebasePieceBinaryStore.downloadBasePdf` is
emulator-verified, not unit-tested (no Storage fake — as with M3.3). Tests:
`default_pdf_binary_cache_test.dart` (7: hit short-circuits, adopt-local,
download+verify+cache, offline re-open, mismatch→retry→fail, download failure,
LRU eviction) + 2 `ScoreBloc` resolve tests + a Noop download-failure test. Full
gate green (incl. golden); the offline-reopen guarantee is proven by the
cache-hit test, the emulator airplane-mode run lands with M3.6.

### M3.5 — `CloudAudioAssetStore` + offline upload queue

**Goal:** Audio notes live in Storage (`/pieces/{id}/audio/{assetId}`)
with an upload queue for notes recorded offline.

**Context.** `AudioAssetStore` contract: `put(sourcePath)→id`,
`pathFor(id)`, `delete(id)`; `LocalAudioAssetStore` copies into
`{documents}/audio_notes/`. Asset ids are local-generated
(`audio_<micros>_<seq>`); notes reference `audioAssetId` only.
**Wrinkle:** `put` today has no piece context, but the Storage path needs
`pieceId` — widen the contract to `put(sourcePath, {required String
pieceId})` (update `ScoreViewerScreen._saveAudioNote` call site, fakes,
and `review_sync`'s import re-`put`s) — G3 blast-radius task.

**Steps**
1. Widen the contract as above; sweep implementations
   (`LocalAudioAssetStore`, harness fakes in
   `apps/duet/test/duet_flow_harness.dart`, `main_screenshot.dart`).
2. `CloudAudioAssetStore implements AudioAssetStore`: `put` = write-local
   (existing layout, the cache) + enqueue upload; `pathFor` = local hit or
   download-and-cache; `delete` = tombstone-friendly remote delete + local
   evict.
3. Upload queue: persisted (`local_storage` key `audio.upload_queue`),
   drains on connectivity/app-start, retries with backoff, survives kill;
   emits status the sync badge can consume (M4.1 reads pending count).
4. Rules already scope audio writes to participants (M2.2).
5. Tests: offline `put` → queue entry → drain uploads (fake storage);
   `pathFor` cache/download paths; queue persistence across restarts.

**Done when:** record-offline → reconnect → collaborator hears the note on
the emulator (covered by M3.8's E2E); gate green.

**Landed.** Widened `AudioAssetStore` so **every** op is piece-scoped —
`put`/`pathFor`/`delete` each take `{required String pieceId}` (the Storage
object is `pieces/{pieceId}/audio/{assetId}`, needed by all three, not just
`put`). Swept: `LocalAudioAssetStore` (ignores `pieceId` — its on-device
layout is one flat `audio_notes/` dir keyed by asset id), the
`ScoreViewerScreen` call sites (`_saveAudioNote`, `_playNote`),
`review_sync`'s import/export re-`put`/`pathFor`/`delete`,
`LocalPieceRepository.deletePiece`, and the harness/screenshot fakes.
`AudioUploadQueue` (persisted via `LocalStorageService`, key
`audio.upload_queue`): `AudioUploadTask` (pieceId/assetId/localPath/attempts,
JSON round-trip); `enqueue` idempotent by assetId; `drain(uploadOne)`
re-entrant-guarded and **reconciled against current storage** (an enqueue
racing a drain isn't clobbered); a failed upload bumps `attempts` and is
dropped past `maxAttempts` (default 5); exposes `Stream<int> pending` +
`pendingCount` for M4.1's sync badge; survives a restart (fresh instance over
the same storage). `CloudAudioAssetStore implements AudioAssetStore`: `put` =
copy into the on-device `audio_notes/` cache (plays back instantly, survives
the recorder temp file) + enqueue + best-effort `unawaited(drainUploads())`;
`pathFor` = cache hit or download-into-cache (a collaborator's note); `delete`
= best-effort remote delete + local evict. Storage transfer sits behind an
`AudioObjectStore` seam (upload/download/delete by pieceId+assetId) so the
cache/queue orchestration is fake-tested; `FirebaseAudioObjectStore` does the
transfer (`putFile`/`writeToFile`/`delete` swallowing `object-not-found`).
**Deviations (recorded in M2.1 doc):** (1) `pathFor`/`delete` widened too, not
just `put` — every op resolves a per-piece object. (2)
`FirebaseAudioObjectStore` is emulator-verified, not unit-tested (no Storage
fake — as with M3.3/M3.4). (3) **Not wired into DI** — the default/mock branch
keeps the local trio (G2); M3.6 flips `AudioAssetStore` to `CloudAudioAssetStore`
under `useFirebase`. (4) A connectivity-triggered drain is deferred to app
wiring (M4.1 consumes `pending`; the queue exposes `drainUploads` for it) —
`put` still kicks a best-effort drain so an online recording uploads at once.
Tests: `audio_upload_queue_test.dart` (6: idempotent enqueue, drain
clears, retry-on-failure, drop past cap, restart-survival, pending stream) +
`cloud_audio_asset_store_test.dart` (7 over a `_FakeObjectStore`: caches +
enqueues, best-effort upload, offline→reconnect drain, cache-hit no download,
collaborator download, neither-cached-nor-remote fails, delete removes
remote + local). Full gate green (incl. golden); the record-offline →
reconnect → collaborator-hears guarantee is proven end-to-end by M3.8's
emulator E2E.

### M3.6 — DI flip + one-time local→cloud migration

**Goal:** `useFirebase: true` boots on cloud pieces; existing local pieces
are offered a one-time upload on first cloud sign-in.

**Context.** `apps/duet/lib/injection.dart` (~L210–235) pins
`LocalPieceRepository`/`LocalAnnotationRepository`/`LocalAudioAssetStore`
"regardless of `useFirebase`" — this task flips that under `useFirebase:
true` while the default mock branch keeps the local trio (G2).

**Steps**
1. Injection: Firebase branch binds `FirestorePieceRepository`,
   `FirestoreAnnotationRepository`, `CloudAudioAssetStore`,
   `PdfBinaryCache`; default branch unchanged;
   `injection_test.dart` untouched, add assertions for the Firebase
   branch in the emulator E2E instead.
2. Migration service (`apps/duet/lib/data/local_piece_migrator.dart`):
   on first cloud sign-in (flag in `local_storage`,
   `migration.pieces.done.<uid>`), if `LocalPieceRepository` holds pieces
   → offer a dialog ("Upload N sheets to your account") → for each: create
   piece doc (owner = current uid), upload PDF (M3.3 path), write own
   layer/notes (`replaceAuthorSlice`-equivalent bulk write), upload
   referenced audio assets (M3.5), then mark migrated (keep local data as
   cache, do not delete).
3. Collaborator entries in local pieces reference mock uids — migrate
   pieces as owner-only and drop stale collaborators (record this
   limitation in the dialog copy).
4. Update `sendInvite` callable's pre-M3 placeholder check (M2.4 marker):
   owner check now reads the piece doc.
5. Tests: migrator unit test over in-memory repos (N pieces, one failing
   upload → partial-resume on next run); flow harness stays mock (G2).

**Done when:** emulator run: seed local pieces (mock boot), sign into
emulator build, accept migration, both accounts' gallery shows the cloud
piece; **plan-M3 exit** "two emulator accounts see the same piece, ink,
and audio pins live" demonstrably close (E2E lands in M3.8).

**Landed.** **DI flip.** `configureDependencies` now branches the piece
storage trio on `useFirebase`: the Firebase branch binds
`FirestorePieceRepository`, `FirestoreAnnotationRepository`, and (audio)
`CloudAudioAssetStore` over an `AudioUploadQueue` singleton +
`FirebaseAudioObjectStore`; the default/mock branch keeps the local trio
unchanged (G2 — the Firestore/cloud objects are never constructed headless).
The Firestore pair has no constructor cycle (neither reads the other) so they
register directly; `PdfBinaryCache`/`PieceBinaryStore` already branched (M3.3/
M3.4). `injection_test.dart` (mock branch) is untouched.
**Migrator.** `LocalPieceMigrator` (`data/local_piece_migrator.dart`) reads
through the local repositories and writes through the cloud ones, so it's
fully fake-testable. Per piece: re-create the Firestore doc **preserving the
piece id** with `ownerId` = the signed-in uid (the local pieces were the mock
identity's), upload the base PDF (M3.3 `uploadBasePdf`, checksum-deduped),
then re-attribute the **owner's own** ink layer + audio notes to the new uid
and write them as one owner slice (`replaceAuthorSlice`) — each audio object
re-uploaded via `AudioAssetStore.put` (fresh `assetId`, re-keyed on the note).
Local collaborators (mock uids) and other authors' layers are dropped
(owner-only). **Resumable:** a per-uid migrated-id set
(`migration.pieces.migrated.<uid>`) skips done pieces and retries failures;
a retry converges (piece-doc create reuses an existing doc, PDF upload
dedupes, the slice write is a full replace). Local data is kept as a cache,
never deleted. **Trigger.** `MigrationPrompt` (`ui/migration_prompt.dart`, a
render-nothing widget in `HomeScreen`) fires a post-frame check on first cloud
sign-in: guarded by the per-uid `migration.pieces.done.<uid>` flag and a
`getIt.isRegistered<LocalPieceMigrator>()` gate (so it's a pure no-op in the
mock composition), it offers a `confirmDialog` ("Upload N sheets…") and runs
the migration on accept, reporting the result in a SnackBar.
**sendInvite owner check.** The callable now reads `pieces/{id}` and rejects a
non-owner (`permission-denied`) / missing piece (`not-found`) before writing
an inbox doc — the M2.4 placeholder that trusted the caller is gone.
**Deviations (recorded in M2.1 doc's migration section):** (1) migration
re-attributes only the **owner's** slice (layer where `ownerId ==
piece.ownerId`) — a piece the local user only collaborated on migrates its
owner's slice; refined multi-author handling isn't needed for the single-user
local case. (2) The per-piece collaborator **cap** stays deferred — enforcing
it needs the owner's pro tier, unknowable server-side until M6.3
(`collaboratorLimits.ts`). (3) `acceptInvite`'s server-side transactional
participant-add is **not** in this task (plan step 4 scoped M3.6 to
`sendInvite`); the cross-account invite→see flow completes with M3.8's E2E.
(4) The migrator/prompt are **Firebase-only glue** — the emulator round-trip
lands with M3.8; here `local_piece_migrator_test.dart` (6: re-own+upload+slice,
owner-only drop, no-annotations piece, skip-on-rerun, resumable retry,
pendingCount) fake-tests the orchestration and the functions suite gains the
two owner-check cases. Full gate green.

### M3.7 — Per-user last-opened watermark + real unread signal

**Goal:** "Shared with me" unread dots reflect reality: content updated
since I last opened.

**Context.** `LibraryState.isUnread`
(`feature_library/lib/src/bloc/library_state.dart` ~L78–91) is a
documented placeholder (`updatedAt > createdAt && !viewedPieceIds`),
session-local via the `PieceViewed` event. The schema slot is
`/pieces/{id}/reads/{uid}` (M2.1/M2.2 done).

**Steps**
1. Contract: add `Future<Result<void>> markOpened(String pieceId)` and
   expose `lastOpenedAt` — cleanest: `watchPieces()` returns pieces plus
   read-state; to avoid entity churn add a small
   `PieceReadStates` watch on the repository (decide shape in
   implementation, document in M2.1 doc). Local impl: persist in
   `local_storage` (`pieces.reads.<uid>` map) so the mock path behaves
   identically.
2. `LibraryBloc`: `PieceViewed` → `markOpened`; `isUnread(piece)` becomes
   `piece.updatedAt > lastOpenedAt(piece)` (never-opened ⇒ unread only if
   shared-with-me; owner's own new imports shouldn't dot themselves —
   preserve current UX assertions in `library_bloc_test.dart`).
3. Reader marks opened on `ScoreOpened` success (app glue in
   `DuetScorePage`), not just from the gallery tap.
4. Piece content changes must bump `pieces.updatedAt` — annotation writes
   don't touch the piece doc; add a lightweight Functions trigger
   (`onLayerWrite`/`onNoteWrite` → bump parent `updatedAt`) or a
   client-side transactional touch — **decide via M2.1 doc** (recommend
   the Function: collaborators' rules can't update the piece doc). This
   detail is what makes unread dots actually fire cross-user.
5. Tests: bloc tests replacing the placeholder-heuristic ones; emulator
   assertion goes into M3.8's E2E (B annotates → A's gallery dots).

**Done when:** dots appear for the collaborator and clear on open, across
two emulator accounts; `unreadSharedCount` badges
(`library_screen.dart` filter chips/pills) keep their widget tests green.

**Landed.** **Contract.** `PieceRepository` gained `markOpened(pieceId)` +
`watchReads() → Stream<Map<String, DateTime>>` (pieceId → the caller's
`lastOpenedAt`). The **local** repo persists a per-uid `pieces.reads.<uid>`
JSON map and emits over a broadcast controller; the **cloud** repo writes
`pieces/{id}/reads/{uid} = {uid, lastOpenedAt}` and watches all of the
caller's watermarks with one `collectionGroup('reads').where('uid', ==, me)`
listener. The `uid` field mirrors the doc id because a collection-group query
can't filter on it, and a new `match /{path=**}/reads/{uid}` rule authorizes
the query (`resource.data.uid == request.auth.uid`); direct get/write stay on
the per-piece `reads/{uid}` rule (rules test + repo tests added).
**Unread signal.** `LibraryState` swapped its session-local `viewedPieceIds`
set for a persisted `lastOpenedAt` map; `isUnread(piece)` is now *shared-with-me
AND `updatedAt.isAfter(lastOpenedAt[id])`* (a missing entry = never opened =
unread) — an owner's own sheet **never** dots. `LibraryBloc` combines
`watchPieces` + `watchReads`; `PieceViewed` optimistically clears the dot then
calls `markOpened` (the stream reconciles). The reader also marks opened on
`ScoreOpened` success (`ScoreBloc`), so a deep-linked open clears it too.
**Cross-user fire.** Annotation writes never touch the piece doc and a
collaborator's rules can't update it, so `onLayerWrite` / `onNoteWrite`
Firestore triggers bump `pieces/{id}.updatedAt` (a `Timestamp`) on each
layer/note create/update — and advance the *editing* author's own
`reads/{uid}.lastOpenedAt` to the **same** instant, so an author never dots
their own edit while every other participant does. Removals are skipped; no
trigger loop (it writes the piece + a `reads` doc, neither a layer/note).
**Deviations (recorded in M2.1 doc):** (1) the read-watermark doc gained a
`uid` field (for the collection-group query) beyond the schema's original
`{lastOpenedAt}`. (2) The trigger also advancing the editor's watermark is
past a literal "bump `updatedAt`", but it's what prevents self-dotting
server-side (no client clock-skew hack). (3) `LibraryBloc` gained an optional
`clock` for the optimistic stamp (defaults to `DateTime.now`). Tests: rewrote
the two placeholder-heuristic `library_bloc_test` cases against the watermark
model (shared-piece dot appears/clears + `markOpened` verified; owner's own
never counts; opened-after vs opened-before), repo read-state tests (local +
Firestore fakes), the collection-group rules test, and the `onLayerWrite`/
`onNoteWrite` functions tests; regenerated the library gallery goldens (owner
sheets lose their dot, one shared sheet reads unread and one read). Full gate
green (format-check/lint/test/golden + functions tsc/eslint/vitest + rules).
The cross-account emulator proof (B annotates → A's gallery dots) lands with
M3.8's E2E.

### M3.8 — Delete cascade + purge v2 + cloud-pieces emulator E2E

**Goal:** Deleting a piece (or an account) leaves no orphans; one E2E
proves the whole M3 loop — the plan-M3 exit.

**Steps**
1. Function `onPieceDeleted` (v2 Firestore trigger): recursive-delete
   `layers`/`notes`/`reads` subcollections + Storage prefix
   `/pieces/{id}/`.
2. Extend `deleteAccount` (M1.8, at the `M3.8 extends` marker): delete
   owned pieces (trigger cascades), remove uid from other pieces'
   `participantIds`/`collaborators`, delete authored layer/note docs in
   pieces the user collaborated on, delete their audio objects.
3. New `integration_test/cloud_pieces_flow_test.dart` (emulator): owner
   imports (upload) → invites (M2.4 callables) → collaborator accepts →
   both `watch` the piece → collaborator draws + records audio → owner
   sees stroke + pin live → offline edit on one side → reconnect →
   converged layers → owner deletes piece → collaborator's gallery
   empties, storage prefix gone.
4. Update the `duet-emulator` skill E2E recipe to mention both flow tests.

**Done when:** E2E green locally per skill recipe; functions tests cover
the cascade; plan-M3 exit met ("two emulator accounts see the same piece,
ink, and audio pins live; offline edit → reconnect converges; emulator E2E
covers the loop").

**Landed — the plan-M3 exit.** **Cascade** (`onPieceDeleted`, a v2
`onDocumentDeleted` trigger on `pieces/{id}`): the piece's `layers`/`notes`/
`reads` subcollections outlive the deleted doc, so it `recursiveDelete`s them
(firebase-admin ^13) and deletes the whole `pieces/{id}/` Storage prefix
(base.pdf + audio). Storage cleanup is best-effort (a new `bucket()` accessor
in `firebase.ts`; wrapped so a bucketless unit test can't crash it) — the
Firestore cascade is functions-tested, the Storage sweep is emulator/E2E-
verified. **`deleteAccount` extended** (at the old `M3.8 extends` marker): one
`participantIds array-contains` query gets the caller's pieces; owned ones are
deleted whole (the cascade sweeps the rest), and for pieces they only
collaborated on the caller is removed from `participantIds`/`collaborators` and
the slice they authored (their layer doc, their notes, each note's Storage
audio object) is deleted; the summary gained `ownedPieces`/`leftPieces`.
**`acceptInvite` completed** (the M3.6-deferred marker): it now transactionally
adds the caller to `participantIds` + `collaborators` (idempotent), which is
what lets a collaborator's `watchPieces` actually see the sheet — the client
(`CallableCollaboratorInviteService`) no longer does the rules-denied on-device
`addCollaborator`, it passes the accepter's name/email to the callable. The
per-piece **cap stays deferred to M6.3** (needs the owner's pro tier
server-side). **E2E** `integration_test/cloud_pieces_flow_test.dart` (emulator,
opt-in via `melos run e2e`, excluded from the headless gate like its siblings)
drives the whole loop at the repository/service layer: owner import + upload →
invite → collaborator accept → sees it → offline stroke + audio note →
reconnect → owner sees both live → owner deletes → collaborator gallery empties
+ Storage prefix gone. `main_emulator.dart` now wires the Storage emulator too;
the `duet-emulator` skill lists the new test. **Deviations:** (1) the cap
enforcement in `acceptInvite` is deferred to M6.3 (owner pro tier). (2) The E2E
is repository/service-level (not full UI-drive), mirroring
`collaborator_flow_test`, and is human/CI-run against the emulator — the
headless gate proves the server logic via the functions vitest (32 tests incl.
the cascade, the participant-add, and the piece-purge) + the rules suite.
Functions `tsc`/`eslint`/`vitest` green; full workspace gate green. **Plan M3
is complete.**

---

## M4 — Live collaboration in the reader

Covers plan M4: real sync badge (M4.1), bundle demotion + nudges (M4.2),
attention loop (M4.3), tombstone semantics (M4.4), and the CI/staging exit
(M4.5). Starts once M3.2 exists; M4 and M5 can proceed in parallel.

### M4.1 — `ScoreSyncStatus` wired to real repository state

**Goal:** The top-bar badge and Layers-panel prompt reflect pending
writes/connectivity, not a session-local `setState`.

**Context.** `ScoreSyncStatus {synced, syncing, notSynced}` is a
presentational enum in
`feature_score/lib/src/ui/widgets/sync_status_badge.dart` (doc: "wiring a
live value in is app-glue work for a later phase"). It's threaded as a
plain constructor param (`ScoreViewerScreen.syncStatus`, default
`notSynced`) and set today only inside `apps/duet/lib/ui/score_page.dart`
`_share`/`_import` via `setState`. `ScoreState` has no sync field.

**Steps**
1. New domain seam in `pieces`: `PieceSyncMonitor` —
   `Stream<PieceSyncState> watch(String pieceId)` where `PieceSyncState
   {synced, syncing, offline}` derives from: Firestore snapshot metadata
   (`includeMetadataChanges: true` → `hasPendingWrites`) on the piece's
   layers/notes + the M3.5 audio upload-queue depth + connectivity.
   Firebase impl in `pieces`; local impl = always `synced`.
2. App glue: `DuetScorePage` subscribes and maps `PieceSyncState` →
   `ScoreSyncStatus` (offline → `notSynced` with the existing
   `cloud_off_outlined` badge — copy review: "Offline — changes saved on
   this iPad"), passing it down; delete the `_syncStatus` `setState`
   plumbing.
3. Keep `ScoreViewerScreen`'s constructor param (feature stays
   presentation-only; G3).
4. Tests: monitor unit tests (fake streams); widget test that badge
   transitions render (`reader_top_bar_test.dart` already covers badge
   priority — extend for transitions); goldens for the three states exist
   — verify unchanged.

**Done when:** on the emulator, going offline flips the badge, an offline
stroke shows "Syncing…" on reconnect until flushed, then "Synced"; gate +
goldens green.

**Landed.** **Domain seam.** New `PieceSyncMonitor` contract +
`PieceSyncState {synced, syncing, offline}` in the domain kernel
(`domain/src/domain/piece_sync_monitor.dart`), with the Firebase-free
`LocalPieceSyncMonitor` (always `synced` — the on-device store has no remote
to fall behind) beside the other local impls. **Firebase impl.**
`FirestorePieceSyncMonitor` (`data/`) folds three live signals into a
de-duplicated state stream: the piece's `layers` + `notes` snapshot metadata
(`includeMetadataChanges: true` → `isFromCache`/`hasPendingWrites`) and the
M3.5 audio upload-queue depth. **Precedence** (`pieceSyncStateFrom`): any
un-acked local write ⇒ `syncing`; else a cache-only read ⇒ `offline`; else
`synced`. Pending outranks offline so the airplane-mode demo (no pending
writes) reads offline while an online edit reads syncing→synced without
flashing offline. Offline is derived from Firestore's own `isFromCache` — no
new `connectivity_*` dependency. **App glue.** `DuetScorePage` now drives the
badge from `PieceSyncMonitor.watch(pieceId)` via a `StreamBuilder`
(`PieceSyncState`→`ScoreSyncStatus`; `offline`→`notSynced`, the
`cloud_off_outlined` pill — copy intent "Offline — changes saved on this
iPad"); the session-local `_syncStatus` `setState` plumbing in
`_share`/`_import` is gone. **G3 preserved:** `ScoreViewerScreen.syncStatus`
stays a plain presentational param; the `score` feature never sees the
monitor. **DI:** registered in both branches (Firestore under `useFirebase`,
local otherwise), so the headless gate stays Firebase-free (G2). **Tests:**
`pieceSyncStateFrom` matrix + `combinePieceSyncSignals` fake-stream
transitions (incl. the offline→syncing→synced reader narrative), the local
monitor, an `injection_test` binding assertion, and a `reader_top_bar`
transition test; the three reader-bar goldens verified **unchanged** (the
badge widget is untouched). The hand-rolled DI in
`app_deep_link_redirect_test` gained the local monitor registration. Full
workspace gate green.

### M4.2 — Demote bundle affordances; "nudge collaborator"

**Goal:** `.duet` bundles leave the primary reader UI (kept as the
airplane-mode escape hatch — architecture decision 3); share affordances
become collaborator nudges.

**Context.** Reader affordances today: overflow menu items "Share my
annotations" / "Import review bundle"
(`reader_top_bar.dart` `_OverflowMenu`), the Layers-panel `_ShareCard`
("Annotations not shared yet" + Share), and the save-note snackbar action
"Share now" (`score_viewer_screen.dart` `_saveAudioNote`,
`actionLabel: 'Share now'`). All route to
`onShareRequested`/`onImportRequested` provided by
`apps/duet/lib/ui/score_page.dart` `_share`/`_import`
(`ReviewSyncService`).

**Steps**
1. Move bundle export/import to the piece detail screen
   (`feature_library`'s `PieceDetailScreen`) under an "Offline sharing"
   section — new callbacks wired from Duet app glue; reader overflow
   drops both items.
2. Repurpose `onShareRequested` → `onNudgeRequested`: sends a `nudge`-type
   `UserMessage` through the M2.4 send path (server-side function; until
   M5.3 ships, delivery is the foreground inbox bridge — note in code
   that push activates with M5.3; the interface doesn't change).
   Layers-panel `_ShareCard` copy becomes "Let <name> know you added
   notes" with a "Nudge" button; save-note snackbar action becomes
   "Nudge" (sends the same).
3. Nudge payload: `{type: 'nudge', pieceId, fromName}` — tap-through
   routing lands in M5.5.
4. Update tests/goldens: `reader_top_bar_test.dart` (menu contents),
   `layers_panel_test.dart` + goldens (new copy),
   `piece_detail_screen_test.dart` (new section), snackbar action test.
5. `ScoreSyncStatus` no longer has any tie to bundles (M4.1 landed) —
   `annotationsShared` input to `LayersPanel` now derives from real sync.

**Done when:** reader shows no bundle UI; nudge lands in the other
account's inbox (emulator); bundle flow still works from piece detail
(escape hatch preserved); gate + goldens green.

**Landed.** **Nudge send path.** New `NudgeService` seam (feature_pairing)
— a `<name> added notes` ping distinct from an access-granting invite.
`DefaultNudgeService` resolves the piece's participants and sends a
`nudge`-type `UserMessage` (`{type, pieceId, fromName}`) to each *other*
participant through the in-memory gateway (the existing foreground inbox
bridge surfaces it; push activates with M5.3, interface unchanged). Under
Firebase the send is server-authoritative via a new **`sendNudge` Cloud
Function** — clients can't create `userInbox` docs (M2.4), so the callable
verifies the caller is a participant (`pieces/{id}.participantIds`), derives
`fromName` from the caller's token (not client-trusted), and fans out with
the Admin SDK. `CallableNudgeService` wraps it; DI binds callable under
`useFirebase`, default otherwise (G2). **Reader UI.** The overflow menu
drops both bundle items; `onShareRequested`/`onImportRequested` collapse to
one `onNudgeRequested`; the Layers-panel prompt is now
`Let <name> know you added notes` + **Nudge** (target resolved from the
piece's other participants — one name, "your collaborators", or hidden when
solo); the save-note snackbar action is **Nudge**. `feature_score` stays
presentation-only (G3). **Offline sharing.** Bundle export/import move to a
new **"Offline sharing"** section on `PieceDetailScreen`, wired from app
glue (`ReviewSyncService` + file picker) threaded LibraryPage →
LibraryHomeScreen → PieceDetailPage — escape hatch preserved, off the
reader. **Tests:** `DefaultNudgeService` (fan-out / self-exclusion / solo
no-op / failure), `sendNudge` vitest (auth, participant gate, fan-out, name
fallback — 38 functions tests green), piece-detail Offline-sharing section,
reader-bar menu + layers-panel nudge copy, injection bindings; layers-panel
golden reshot for the nudge card, reader-bar goldens **unchanged**. Full
workspace gate + functions tsc/eslint/vitest green.

### M4.3 — Attention loop: per-layer new-annotation markers + audio-pin "new"

**Goal:** A collaborator opening a shared sheet sees *what changed since
they last looked*.

**Context.** No new/unseen concept exists in the reader
(`AudioPinMarker` has only playing/ownership states). The watermark store
(`reads/{uid}`, M3.7) provides `lastOpenedAt`.

**Steps**
1. Thread `lastOpenedAt` into `ScoreBloc` (via `ScoreOpened` payload or
   repository read) — captured **at open time** before `markOpened`
   bumps it.
2. Derive per-layer newness: layer `updatedAt > lastOpenedAt` (schema has
   `updatedAt` per layer doc) → `ParticipantLayer` gains `hasNewInk`;
   `LayersPanel._LayerRow` shows a dot + semantics ("…, new annotations");
   note newness: `AudioNote.createdAt > lastOpenedAt` → `AudioPinMarker`
   gains `isNew` (ring/dot accent, drop after first play — playing marks
   seen locally).
3. Page rail: `PageInkPresence` gains a `hasNew` flag so the rail hints
   which pages have fresh ink (small accent on `_PageThumb`).
4. Session semantics: newness computed once per open (not live-decaying
   mid-session); simple and predictable.
5. Tests: bloc projection tests (fixed clock); widget tests for
   layer-row dot and pin state; goldens for `AudioPinMarker` new-state and
   layers panel.

**Done when:** two-account emulator check: B annotates while A is away; A
reopens and sees layer dot + new pin; markers gone on next reopen; gate +
goldens green.

**Landed.** **Newness source.** `InkLayer` gained `updatedAt` (mapped from the
cloud layer doc's `updatedAt`; `null` on the on-device store, so the mock path
shows no cross-participant newness — G2). **The reader is the single watermark
writer.** `ScoreBloc._onOpened` reads the viewer's `lastOpenedAt` itself from
`watchReads().first[pieceId]` **before** its own `markOpened` bumps it (the
one-shot read resolves immediately — the local `watchReads` yields the current
map on subscribe; a best-effort `_readWatermark` folds any stream error to
`null`). `ScoreOpened` carries only the id. The gallery tap
(`LibraryBloc._onPieceViewed`) now *optimistically* clears the dot but no longer
persists `markOpened`, and opening the Piece Detail screen doesn't mark viewed
at all — so the reader's pre-open capture can't lose a race to the library's
own on-tap write (the review-caught bug: the library bumped the watermark
before the reader read it, defeating newness on the primary open path).
`score_bloc_test` stubs `watchReads` accordingly, including a stateful stub
proving the captured value is the pre-`markOpened` one. **Bloc
projection.** `ScoreBloc` derives `ParticipantLayer.hasNewInk`
(`layer.updatedAt > lastOpenedAt`, never the viewer's own, false when either is
null) and `ScoreState.isNoteNew` (`note.createdAt > lastOpenedAt`, other author,
not yet played). Newness is computed once per open and clears on the next
reopen (that reopen's `markOpened` advanced the watermark); the only mid-session
decay is the `AudioNotePlayed` event, which adds the note to a session-local
`seenNoteIds` so playing a "new" note drops its marker. **UI.** Layers-panel
`_LayerRow` shows a primary dot + ", new annotations" semantics;
`AudioPinMarker` gains a corner "new" badge (hidden while playing);
`PageInkPresence` gained `hasNew`, hinting fresh ink/notes on the page rail's
`_PageThumb`. **Tests:** bloc projection (fixed dates) for
hasNewInk/isNoteNew/play-drops-marker; widget tests for the layer-row dot, pin
new-state, and page-rail accent + semantics; goldens reshot for the pin
new-badge, page rail, and the layers-panel dot (the `clean_workspace` layers
golden reshot too — same shared fixture). Full workspace gate + score goldens
green.

### M4.4 — Soft-delete tombstones for audio notes

**Goal:** Deleting a note converges across offline peers instead of
resurrecting (plan M4 "cross-device delete/edit semantics").

**Context.** Deletes are physical everywhere today
(`LocalAnnotationRepository.deleteAudioNote` filters the note out;
Firestore impl M3.2 mirrored it). Schema already reserves `deletedAt`
(M2.1) and rules restrict note updates to tombstoning (M2.2).

**Steps**
1. `AudioNote` gains `DateTime? deletedAt` (mappers, `props`, both
   repos). `deleteAudioNote` ⇒ set `deletedAt` (author-only, unchanged
   guard); `watch` filters tombstones out of `PieceAnnotations` (blocs/UI
   never see them — zero UI change).
2. Asset handling: keep the Storage object until tombstone GC; add a
   scheduled Function (`gcTombstones`, daily) that hard-deletes notes
   (doc + audio object) with `deletedAt > 30d`.
3. Local repo mirrors tombstone semantics (so bundle/local paths converge
   identically); `review_sync` manifests include tombstoned notes so
   offline bundles also converge (`replaceAuthorSlice` carries them).
4. Ink strokes: **explicitly out of scope** — erases are own-layer doc
   rewrites, which converge by last-writer-wins on a single-author doc;
   record this rationale in the M2.1 doc.
5. Tests: offline-delete convergence (A deletes offline, B added nothing
   → reconnect → note gone on both; A deletes while B plays → B's next
   watch emission drops it); GC function test.

**Done when:** convergence tests green on emulator; no resurrection after
reconnect; gate green.

**Landed.** **Domain.** `AudioNote` gained `DateTime? deletedAt` (+ `copyWith`,
`isTombstoned`, `props`); both mappers round-trip it (local JSON: nullable
ISO-8601; Firestore: `Timestamp?`). **Repos.** `deleteAudioNote` now sets
`deletedAt` instead of removing the note — the local repo keeps it in storage
(a delete on an already-tombstoned note reads as unknown, matching the cloud
repo); the Firestore repo issues `update({deletedAt})` (the only note mutation
the M2.2 rules permit). Both `watch`es hide tombstoned notes, so blocs/UI are
unchanged; a new `snapshotWithTombstones` on the contract exposes the raw set
for one caller only — the review-sync export. **Bundles.**
`ManifestAudioEntry.audioFile` went nullable and the manifest round-trips
`deletedAtMillis`; `exportBundle` reads `snapshotWithTombstones` and packages a
tombstone as a metadata-only entry (no audio bytes), while `importBundle`
applies it through `replaceAuthorSlice` so an offline peer drops the note
instead of resurrecting it (summary/notification count only live notes).
**GC.** `gcTombstones` (scheduled, daily) collection-group-queries `notes` for
`deletedAt` ≤ now−30d and hard-deletes the doc + its `audio/{assetId}` Storage
object; a type guard skips live notes (`deletedAt: null` sorts before every
timestamp, so it can slip the `<=` filter). **Ink is out of scope** — erases
are single-author `layers/{uid}` rewrites that converge by last-writer-wins on
one doc, nothing to resurrect (rationale recorded in the M2.1 schema doc).
**Tests:** local + Firestore repo tombstone (watch hides / doc survives with
`deletedAt` / fresh repo never resurrects / snapshot retains); both mapper
round-trips; a review-sync bundle convergence test (sender tombstones → export
→ receiver's live copy drops on import, tombstone retained); and a `vitest`
`gcTombstones` suite (expired swept, fresh + live kept, collection-group span).
Full workspace gate + functions suite green.

### M4.5 — Reader E2E against the emulator in CI

**Goal:** The plan-M4 exit: reader collaboration suite runs against the
emulator **in CI** (two physical devices on staging is the human half).

**Steps**
1. Consolidate the emulator suites (`collaborator_flow_test.dart`,
   `auth_lifecycle_test.dart` M1.10, `cloud_pieces_flow_test.dart` M3.8,
   plus reader assertions from M4.1–M4.4) under a melos script
   `e2e-emulator`: `firebase emulators:exec --only
   auth,firestore,functions,storage 'flutter test integration_test -d
   chrome'` from `apps/duet` (the `duet-emulator` skill documents the
   `-d chrome` pattern; headless Chrome + Java on the runner).
2. CI job `emulator-e2e` in `ci.yaml`: Flutter + Java + Chrome + node;
   cache the functions build; run on PRs touching
   `apps/duet/**` or `packages/**` (path filter to keep unrelated PRs
   fast). Known-fiddly: if `flutter test -d chrome` proves flaky on the
   runner, fall back to `flutter drive -d web-server` and document it in
   the workflow file.
3. **[HUMAN, Track B]** Two-device staging session: annotate the same
   sheet in real time; capture screen recordings for the launch
   material; log latency observations into M8's budget doc. (Track A
   already covers real hardware: `dev_device.sh` drives physical devices
   against the LAN emulators.)

**Done when (Track A):** the CI job is green and required; a deliberately
broken sync assertion fails it. **(▸B):** the staging demo recording
lands with Track B — then the plan-M4 exit is fully met.

**Landed (Track A artifacts).** A single turnkey **`melos run e2e-emulator`**
script boots Auth+Firestore+Functions+Storage via `firebase emulators:exec`
(rebuilding the functions first so the emulator serves the current
callables/triggers) and runs the emulator-backed flows (`auth_lifecycle`
M1.10, `cloud_pieces_flow` M3.8, `collaborator_flow`) plus the reader
assertions of M4.1–M4.4 from `apps/duet`. It uses `npx --yes firebase-tools`
so it runs with or without a global CLI (matching `dev.sh`). The
**`emulator-e2e`** CI job (ci.yaml) wires Flutter + Node + Java + cached
emulator binaries around it, gated by a `dorny/paths-filter` `changes` job so
it only runs on PRs touching `apps/duet/**`/`packages/**`/`melos.yaml`/
`ci.yaml` (per-job filter — a workflow-level `on.paths` would wrongly gate
every job).

**Blocked on a platform limitation — the CI job is non-blocking for now.** The
M4.5 review caught that two of the three suites (`cloud_pieces_flow`,
`auth_lifecycle`) use `dart:io` (`File`/`Directory`/`HttpClient`), which the
Flutter **web** target (`-d chrome`) lacks — so they can't run headlessly on a
runner (they throw `UnsupportedError: _Namespace`). The repo's own test
headers documented that `-d chrome` pattern, but it was aspirational. So the
`emulator-e2e` job is `continue-on-error: true` (visible, not blocking) until
the real fix: either a **native-device runner** (`flutter drive -d <device>`,
where `dart:io` + native Firebase plugins coexist — matching the suites' "needs
a device" headers) or **refactoring the two suites off `dart:io`** (`HttpClient`
→ `package:http`; `File` uploads → in-memory `putData`). The turnkey script
stays usable locally/on a device today. **CI hygiene:** the workflow's Flutter
is pinned to `3.44.6` (this repo's dev version) because the floating `stable`
channel had drifted the Firebase ecosystem (`firebase_core 4.12.0` /
`cloud_firestore 6.7.0`) to versions referencing a `FirebasePlugin` the
resolvable `firebase_core` lacks, reddening `analyze-and-test` repo-wide;
the pin reproduces the known-good local resolution.

**Remainder (human/admin):** making the check **"required"** is a repo
branch-protection setting (admin), and the **▸B two-device staging demo** is
Track-B/human — both on top of the platform fix above.

---

## M5 — Invites, deep links, push

Covers plan M5: real `DeepLinkService` + Universal/App Links + fallback
page (M5.1), single-use expiring token docs (M5.2), the three Functions
behaviors — invite push, digest push, token pruning (M5.3, M5.4;
inbox-write authorization landed in M2.4), tap-through to the exact piece
(M5.5), plus the invite-inbox UI the plan implies but never names (M5.6)
and the staging exit + skill update (M5.7). **Track note:** M5.2/M5.6 are
pure Track A; M5.3/M5.4/M5.5 build in Track A with mocked delivery (no
FCM emulator exists); M5.H/M5.1/M5.7 are Track B.

### M5.H — [HUMAN] Invite-link domain

- Choose/purchase the custom domain (default `link.<app-domain>`), point
  it at Firebase Hosting (M0.4's site), and record it in
  `docs/duet_environments.md`.
- Provide the iOS Team ID + Android signing SHA-256s for the association
  files (M5.1 embeds them).

### M5.1 — Real `DeepLinkService` + Universal/App Links + fallback page

**Goal:** `https://<domain>/invite/<token>` opens the app (or a helpful
page), replacing `FakeDeepLinkService`. Firebase Dynamic Links is sunset —
nothing uses it (architecture decision 4).

**Context.** The production-grade service **already exists**:
`AppLinksDeepLinkService` in `packages/services/deep_linking` (wraps
`app_links`, takes a parser; `showcase` wires it). Duet wires
`FakeDeepLinkService` (`apps/duet/lib/data/fake_deep_link_service.dart`)
in `injection.dart` L275. The parser (`duetDeepLinkParser`,
`apps/duet/lib/routing/app_deep_link_parser.dart`) already maps invite
URIs → `/invite/accept/<token>`; `InviteDeepLinks.buildUri` currently
hardcodes `https://duet.app/...` (`feature_pairing/lib/src/data/
invite_deep_links.dart`).

**Steps**
1. Injection: Firebase branch binds
   `AppLinksDeepLinkService(parser: duetDeepLinkParser)`; mock branch
   keeps the fake (G2; `fake_deep_link_service_test.dart` and
   `app_deep_link_redirect_test.dart` keep passing).
2. Make the link domain configurable (`InviteDeepLinks` takes the domain;
   dart-define or env config per flavor) — dev can use the staging domain.
3. Platform config (needs M0.1 dirs): iOS Associated Domains
   (`applinks:<domain>`) per flavor; Android `intentFilter` with
   `autoVerify` for the domain.
4. Hosting: serve `/.well-known/apple-app-site-association` +
   `/.well-known/assetlinks.json` (Team ID/SHA-256 from M5.H) and a
   fallback page for `/invite/*` — "Open Duet" + store badges + plain
   explanation (no JS tricks); deploy via M0.5 pipeline.
5. Manual verification matrix documented in `apps/duet/README.md`
   (cold-start link, warm link, app-not-installed → fallback page).

**Done when:** tapping a staging invite link on a device with the app
installed opens `/invite/accept/:token` (existing route); without the app,
the fallback page renders; headless tests untouched.

### M5.2 — Invite tokens as single-use, **expiring** Firestore docs

**Goal:** Tokenized invites become server-verifiable: single-use,
expiring, revocable.

**Context (gap to close).** `DeepLinkInviteService`
(`feature_pairing/lib/src/data/deep_link_invite_service.dart`) mints
crypto-random 20-char tokens and stores them in **local storage**
(`pairing.invites`); `consumed` is enforced, but `createdAtMillis` is
**never checked** — expiry is modeled, not enforced. Acceptance mutates
the piece via `pairCollaborator`, which M2.2 rules forbid cross-user.

**Steps**
1. Schema `/inviteTokens/{token}` per M2.1; Firestore **TTL policy** on
   `expiresAt` for cleanup (**[HUMAN]** console/`gcloud` toggle — note
   TTL deletion lags up to ~72 h, so expiry is *always also checked at
   accept time*).
2. Functions: `createInviteToken({pieceId})` — owner-only, cap-checked,
   mints token doc (`expiresAt = now + 14d`), returns the URL;
   `acceptInviteToken({token})` — transaction: exists ∧ !consumed ∧
   !expired → add caller to piece arrays → mark
   `consumed/consumedBy`; typed error codes for expired/consumed/at-cap
   (client maps to `AcceptInviteStatus` states, which already include
   `alreadyCollaborator`/`atCap`).
3. Client: `DeepLinkInviteService` becomes the *mock-path* impl
   (rename or keep, bound only under `useFirebase: false`); a new
   `CloudInviteService implements InviteService` calls the callables.
   `AcceptInviteCubit`/`InviteBloc` unchanged (G3).
4. Rules: `inviteTokens` — no client reads/writes (Functions only);
   resolve-preview (`resolveInvite` for the accept screen's piece title)
   becomes part of `acceptInviteToken`'s first phase or a read-only
   callable `resolveInviteToken`.
5. Tests: functions tests (expired/consumed/at-cap/happy); cubit tests
   against a fake service already exist — extend for expired state copy.

**Done when:** an expired token shows the "invalid or expired" state
(string already exists in `_requireValid`); consumed tokens can't be
reused across two emulator accounts; rules tests deny direct token reads.

**Landed.** Three v2 callables in `functions/src/inviteTokens.ts`:
`createInviteToken` (owner-only, cap-checked, mints `/inviteTokens/{token}`
with `expiresAt = now + 14d`, returns the URL), `resolveInviteToken` (kept a
**separate read-only callable**, not a phase of accept, so opening a link
can never mutate state), and `acceptInviteToken` (one transaction: validate
→ join piece arrays → `consumed`/`consumedBy`; racing accepts contend on the
token doc). Typed denials ride `HttpsError.details.reason`
(`invalid|expired|consumed|at-cap|already-collaborator`). Deviations from
the sketch: (1) the **cap is enforced now**, not deferred to M6.3 — the
owner's tier reads `entitlements/{ownerId}` (absent = free, which is the
pre-M6.3 truth; `ownerIsPro` in `collaboratorLimits.ts`); the M2.4 email
path is untouched. (2) The schema doc's ACL row gave clients create/read on
token docs — implemented **stricter**: `inviteTokens` is fully
Function-only, rules deny all client access (schema doc updated; 4 new
denial tests in `firestore_tests`). (3) `AcceptInviteCubit` is *almost*
unchanged — same contracts (G3), but two behavior fixes were unavoidable:
a fresh invitee's participant-gated `getPiece` denial now reads as `ready`
(pre-M5.2 the piece was always locally readable), and a typed
at-cap/already-collaborator denial from accept maps to its dedicated state.
(4) A token consumed **by the caller** still resolves/reports
`already-collaborator`, so re-opening a redeemed link is friendly; consumed
by anyone else is a hard `consumed`. (5) `onPieceDeleted` also sweeps the
piece's tokens by `pieceId` (TTL is only a lagging backstop). Client:
`CallableInviteService` (`apps/duet/lib/data/`) under `useFirebase: true`;
`DeepLinkInviteService` stays the mock path and now **enforces** the same
14-day TTL (`tokenTtl`) it previously only modeled. **[HUMAN] open:** enable
the Firestore TTL policy on `inviteTokens.expiresAt` (console/gcloud, per
env) — expiry is always also checked at resolve/accept, so this is cleanup
only. Gate green; functions 62/62, rules 49/49 (run `test:against-running`
against the live dev emulators — `emulators:exec` couldn't bind 8080/9099).

### M5.3 — Push fan-out: `onInboxMessageCreated` → FCM + token pruning

**Goal:** Invites (and nudges) reach the invitee's lock screen — the
first real server-side sender.

**Track split:** the function, prune logic, and mocked-messaging tests
are Track A; real delivery (APNs key upload, moving `firebase_messaging`
to a real dependency, lock-screen verification) is the ▸B backlog item —
there is no FCM emulator.

**Context.** `deviceTokens/{uid}` docs (`{tokens: [...]}`) are written by
`DeviceTokenSync` (registered in injection, token sources flip on
`useFirebase`) but **nothing reads them** ("forward-provisioning", per the
contract docs). Local notifications flow through
`NotificationsManager.showLocal` via the `_InboxNotificationBridge`
(injection.dart ~L298–340) — foreground-only.

**Steps**
1. Function `onInboxMessageCreated` (v2 Firestore trigger on
   `userInbox/{uid}/messages/{id}`): read recipient tokens → FCM
   multicast: notification (title/body from the message) + `data:
   {type, pieceId, deepLink: 'https://<domain>/piece/<id>' | invite URL}`.
2. Token pruning: on `messaging/registration-token-not-registered`
   (UNREGISTERED), `arrayRemove` the token from the doc.
3. Foreground dedupe: the client bridge already `markRead`s messages it
   surfaces; FCM notification + local bridge would double-notify in
   foreground — suppress the bridge's `showLocal` when a push
   notification was already displayed (simplest: bridge only runs when
   FCM permission is denied, or mark messages `pushed: true` from the
   function and have the bridge skip those — pick one, document it in
   the bridge's doc comment).
4. iOS: APNs key upload (**[HUMAN]**, console) + `firebase_messaging`
   already a (dev-)dependency — move it to a real dependency of
   `apps/duet`.
5. Functions tests with the FCM emulator-stub pattern (mock `admin
   .messaging()`); prune path unit-tested.

**Done when (Track A):** functions tests green including the prune path;
`deviceTokens`' "nothing reads it" doc comments updated. **(▸B):** an
invite sent from device A shows a system notification on backgrounded
device B (staging, human-verified).

**Landed (Track A).** `functions/src/inboxPush.ts` —
`onInboxMessageCreated` (v2 trigger on `userInbox/{uid}/messages/{id}`)
reads `deviceTokens/{uid}` and multicasts via a new lazy `fcm()` seam in
`firebase.ts` (`admin.messaging()`): notification title/body from the
message, `data` = the message's own map + a `deepLink`
(`https://duet.app/piece/<id>`, placeholder domain kept in sync with
`inviteTokens.ts`, real domain is ▸B). Pruning: any
`messaging/registration-token-not-registered` response `arrayRemove`s that
token. **Foreground dedupe — strategy chosen: `pushed: true`.** After a
successful send (successCount > 0) the function merges `pushed: true` onto
the message doc; `InboxNotificationBridge` skips `showLocal` for
[pushed] messages but still `markRead`s non-action ones (a pushed nudge is
consumed without re-showing; a pushed invite stays unread for accept).
Chosen over "bridge only when permission denied" because it needs no
client-side permission branching, and it also kills the pre-existing
re-notify-on-next-foreground double; a no-token recipient keeps bridge
delivery. The foreground race (bridge fires before the function marks) is
benign — foreground FCM isn't auto-displayed by the OS. `UserMessage`
gained a server-owned `pushed` field (absent → false; G3: Firestore
mapper + docs updated across the notifications package); `deviceTokens`'
"forward-provisioning / nothing reads it" doc comments now name the
function. Tests: `test/inbox_push.test.ts` (mocked
`firebase-admin/messaging`, unique-id style — safe under
`test:against-running`): fan-out happy path incl. `pushed` merge, absent
and empty tokens, prune-keeps-live-tokens, transient-failure keeps token +
leaves `pushed` unset; bridge tests cover pushed-invite/pushed-nudge
skip + mixed snapshots. Functions build/lint/tests 67/67; duet +
notifications analyze/tests green (full workspace gate runs on the
integration branch). ▸B unchanged: APNs key, `firebase_messaging` real
dependency, lock-screen verification.

### M5.4 — Batched annotation digest push

**Goal:** "Maya added 3 notes to Clair de Lune" — bundled, not one push
per stroke.

**Steps**
1. Function `onAnnotationsChanged` (triggers on layer/note writes):
   enqueue `{pieceId, authorId, recipientIds, kind, count}` into a
   `pushDigests` collection instead of sending immediately.
2. Scheduled function (every 10 min) drains digests: group by
   (recipient, piece, author), compose copy ("<author> added <n> notes to
   <title>"), send via the M5.3 sender, delete drained docs. Skip
   recipients whose `reads/{uid}.lastOpenedAt` is newer than the batch
   (they already saw it).
3. Respect the Settings push toggle (`SettingsRepository.readPushEnabled`
   is client-side only — mirror the preference into
   `deviceTokens/{uid}.pushEnabled` on toggle so functions can honor it;
   small client change in `feature_settings` wiring + schema note).
4. Author's own edits never notify the author.
5. Tests: grouping/copy unit tests; scheduled-drain emulator test.

**Done when:** burst of 5 strokes + 2 notes → exactly one digest per
recipient and muted users receive none (asserted in emulator/unit tests —
Track A); real delivery rides M5.3's ▸B backlog item; gate green.

### M5.5 — Notification tap-through → the exact piece

**Goal:** Tap a push → the app opens the sheet (plan M5 bullet 3).

**Track split:** steps 1, 3, and 4 (route, parser, local-notification
taps, tests) are Track A — `FakeDeepLinkService.ingest` drives them; step
2's FCM tap wiring is the ▸B item (needs M5.1/M5.3 live).

**Context (gaps).** The **`/score/:pieceId` route already exists** —
added in the post-M1.3 routing standardization (every full-screen
destination in Duet is a go_router route; `_dispatchIntent` in `app.dart`
navigates signed-in intents with `go` and holds signed-out ones until
login). `DeepLinkService.ingest(Uri)` is the designed seam but is only
called from tests, and `duetDeepLinkParser` doesn't map piece URIs yet.
`PluginLocalNotificationPort.initialize` sets **no**
`onDidReceiveNotificationResponse` (no tap callback, no payload).

**Steps**
1. Routing: extend `duetDeepLinkParser` to map `/piece/<id>` URIs onto
   the existing `/score/:pieceId` route; unknown/denied ids land on
   `/home` with an `AppSnackbar` (G4).
2. **[Track B]** FCM taps: in the Firebase entry points, wire
   `FirebaseMessaging.onMessageOpenedApp` +
   `getInitialMessage()` → extract `data.deepLink` →
   `getIt<DeepLinkService>().ingest(uri)` — the existing
   `onIntent → _dispatchIntent` machinery in `app.dart` does the rest.
3. Local notifications: extend `LocalNotificationPort.show` with a
   `payload` param + a tap stream; `PluginLocalNotificationPort` passes
   `onDidReceiveNotificationResponse`; the inbox bridge sets the piece
   deep link as payload and Duet glue routes taps through `ingest` too
   (contract widening — update `NotificationsManager.showLocal`
   signature, fakes, tests; G3).
4. Tests: parser test for `/piece/<id>`; redirect test mirroring
   `app_deep_link_redirect_test.dart`; widget-level tap-through with the
   fake service (`FakeDeepLinkService.ingest` already fits).

**Done when:** staging: invite push → tap → accept screen; nudge/digest
push → tap → the exact sheet opens — the **plan-M5 exit** path, minus the
two-device demo recorded in M5.7.

**Landed (Track A).** **Routing.** `duetDeepLinkParser` now maps
`https://duet.app/piece/<id>` (exactly the shape M5.3's
`onInboxMessageCreated` emits as `data.deepLink`) onto the existing
`/score/:pieceId` route, re-encoding the id into the location the same way
the invite path does; two-segment `/piece/<id>` only (empty id or trailing
segments fall through to `UnrecognizedLinkException`). That route is now a
push/deep-link destination, so it's guarded (`DuetScoreRouteGuard` in
`ui/score_page.dart`): the id is resolved against `PieceRepository` first,
and an unknown/denied one bounces to `/home` with an `AppSnackbar` (G4)
instead of stranding the user on a dead reader. **Contract widening (G3).**
`LocalNotificationPort.show` gained a `payload` param + an `onTap` payload
stream; `PluginLocalNotificationPort` passes
`onDidReceiveNotificationResponse` and re-emits non-empty payloads.
`NotificationsManager.showLocal` threads `payload` through and exposes
`onLocalNotificationTap`; every fake/mock/test updated (the package's
`_FakeLocalNotificationPort`, duet's mocktail `showLocal` stubs). **Glue.**
The inbox bridge sets each message's piece deep link as the notification
payload (`InboxNotificationBridge.pieceDeepLinkFor`, kept in sync with the
function's `DEEP_LINK_DOMAIN`); a new `NotificationTapRouter` (registered
under `useFirebase` only, so the headless gate never resolves
`NotificationsManager` — FIX-3/G2) `ingest`s tap payloads into
`DeepLinkService`, and `AppView`'s existing `onIntent → _dispatchIntent`
does the rest (signed-in → straight to the piece; signed-out → held until
login). **Tests.** parser `/piece/<id>` valid/re-encoded/garbage;
`notification_tap_router_test.dart` (ingest + drop-unparseable +
parser-decides); three redirect tests mirroring
`app_deep_link_redirect_test.dart` (signed-in opens the exact score,
signed-out held-until-login, unknown-id → `/home` + snackbar); notifications
package payload-threading + tap-stream tests; bridge tests pin the piece
payload (and its absence for a piece-less message). duet analyze +
589 tests green, notifications analyze + 30 tests green (trimmed gate; full
workspace gate runs on the integration branch). **▸B remainder:** FCM
`onMessageOpenedApp`/`getInitialMessage` wiring in the Firebase entry
points → `data.deepLink` → `ingest` — needs M5.1/M0.2 (real
`firebase_messaging` dependency + initialized app), no FCM emulator to
verify against.

### M5.6 — In-app invite inbox UI (email-invite acceptance)

**Goal:** An email-invited user can actually see and accept the invite
inside the app — today `watchInvites`/`acceptInvite` are **only called
from tests**; production invitees get a one-shot local notification and
then nothing.

**Status:** done. Step 4 landed ahead of this milestone (it was blocking
the flow outright, not just the UI — see below); steps 1–3 and 5 — the
banner and its tests — landed after it (see **Landed.**).

**Steps**
1. Library surface: a pending-invites banner/section on `LibraryPage`
   ("Maya invited you to Clair de Lune — Accept / Dismiss"), fed by
   `CollaboratorInviteService.watchInvites(uid)` (already implemented,
   decodes inbox messages of type `invite`).
2. Accept → M2.4 `acceptInvite` callable path (already wired through the
   service); success → gallery live-updates (M3.1 `watchPieces`) + navigate
   to the piece; at-cap → the existing paywall-gate pattern from
   `invite_sheet.dart`'s `_PaywallGateBody`.
3. Dismiss → `markRead` only (sender unaffected).
4. ☑ **Landed early** — inbox messages stay **unread until acted on**.
   This wasn't just a UI prerequisite: the bridge marked *every* message
   it surfaced read, and `acceptInvite` refuses a read message, so an
   invite was consumed the instant the recipient signed in and every
   accept failed with "That invite was already used" — the email flow
   could not complete on any backend, UI or no UI. Found by running the
   flow on two iPads against the emulators.

   Implemented as `UserMessage.requiresAction` (a sender declares that
   *seeing* a message doesn't finish it) rather than this step's original
   sketch of special-casing `invite` **type** in the bridge. Reason:
   `UserMessage` is deliberately domain-agnostic and
   `services/notifications` is reused across apps, so the semantics ride
   the envelope instead of every consumer keeping its own list of which
   types are actionable — adding a message type stays a one-file change
   at the send site. Both senders set it: `DefaultCollaboratorInviteService`
   and the `sendInvite` callable (which writes the inbox doc server-side).
   `InboxNotificationBridge` de-duplicates with a session-scoped set of
   shown ids, is now `@visibleForTesting`, and is covered by
   `apps/duet/test/inbox_notification_bridge_test.dart`.
5. Tests: `duet_flow_test.dart` already drives invite→inbox→accept over
   in-memory fakes — extend it to go through the new banner UI instead of
   calling the service directly; widget tests for the banner states;
   golden for the banner.

**Done when:** email invite (no link involved) is acceptable end-to-end in
UI on the emulator: send from A → banner on B → accept → piece appears in
B's gallery; headless flow test drives the same UI (G2).

**Landed.** Steps 1–3 and 5, as `InviteInboxBanner` +
`InviteInboxCubit` in the pairing feature
(`apps/duet/lib/features/pairing/src/{ui/invite_inbox_banner.dart,
bloc/invite_inbox_cubit.dart}`), composed at the app layer:
`HomeScreen` mounts it above `LibraryPage` next to
`EmailVerificationBanner` (the library feature can't import pairing —
architecture test), wiring `onAccepted` to push `/score/:pieceId` (G8).
One row per pending invite from `watchInvites(uid)`: Accept rides
`CollaboratorInviteService.acceptInvite` (the M2.4 callable under
Firebase); at-cap (`AtCapInviteException`) defers to the invite sheet's
paywall-gate pattern — `PaywallScreen` in a bottom sheet; Dismiss is
`UserMessageGateway.markRead` only. Deviations from the step-1 sketch:
the copy is "{owner} invited you to collaborate on a sheet" — the piece
*title* isn't knowable pre-accept (a non-participant can't read the
piece doc under the M2.2 rules and the invite payload doesn't carry it);
and `DefaultCollaboratorInviteService.acceptInvite` now marks the inbox
message read on success, mirroring the callable's server-side consume,
so the banner clears on accept in every composition. Tests:
`invite_inbox_banner_test.dart` (all states over mocked seams),
light/dark goldens, an accept-consumes case in the service test, and
`duet_flow_test.dart` now drives invite→banner→accept through the real
banner UI over an invitee-scoped library view — empty gallery →
accept → sheet appears (the "Done when" flow, headless).

### M5.7 — Two-device staging validation + skill update

**Goal:** The plan-M5 exit demo, plus tooling docs that match reality.

**Steps**
1. **[HUMAN]** Two physical devices on staging: invite → push → tap →
   sheet opens (record it); link-based invite from a device without the
   app → fallback page → install → deferred open (document behavior —
   no deferred deep linking in 1.0; the link is re-tappable).
2. Update `.claude/skills/duet-device/SKILL.md`: staging-flavor run
   instructions (not just emulator), push-testing notes (APNs sandbox),
   and the functions emulator requirement for local invite testing.
3. File follow-ups discovered during the demo as tasks under M8.4.

**Done when:** recording exists; skill updated; plan-M5 exit checked off.

---

## M6 — Monetization for real

Covers plan M6: RevenueCat swap (M6.1), paywall/restore/billing states
(M6.2), server-side entitlement enforcement (M6.3), Remote Config flags
(M6.4). Can start any time after M1; M6.3 depends on M2.4's callables.
**Track note:** M6.4 is Track A (contract + in-memory fake — there is no
Remote Config emulator, so the fake is the dev path anyway); M6.H and
M6.1–M6.3 are Track B, with the simulated service keeping paywall flows
testable meanwhile. M6.3's function-side cap code can be built on the
emulator earlier if caps matter before monetization goes live.

### M6.H — [HUMAN] RevenueCat + store products

- RevenueCat account; iOS + Android apps configured; API keys per
  platform recorded as dart-defines/secrets (never in-repo).
- App Store Connect + Play Console: create the subscription products
  (monthly, annual — ids recorded in `docs/duet_environments.md`),
  attach to a RevenueCat offering with a `pro` entitlement.
- Sandbox test accounts for both stores.

### M6.1 — Wire `RevenueCatService` (flavor-gated)

**Goal:** Real purchases SDK behind the existing contract.

**Context.** `MonetizationService`
(`packages/core/monetization/lib/src/monetization_service.dart`) is
already RevenueCat-typed (imports `purchases_flutter`; `initialize`,
`logIn/logOut`, offerings, purchase/restore, `isProUser[Stream]` with a
`pro` entitlement id) and **`RevenueCatService` already exists**
(`revenue_cat_service.dart`). Duet binds `SimulatedMonetizationService`
unconditionally (injection.dart ~L81–83).

**Steps**
1. Injection: Firebase branch binds `RevenueCatService`; `initialize(
   apiKey)` from a dart-define per flavor; mock/dev branches keep
   `SimulatedMonetizationService` (G2).
2. Identity linking: on auth `account` stream — sign-in → `logIn(uid)`,
   sign-out → `logOut()` (small glue listener next to the directory
   upsert listener; entitlement must survive reinstall via the store
   account, and `logIn` ties it to the app account).
3. Confirm `purchases_flutter` platform requirements against the M0.1
   platform dirs (min SDK versions).
4. Tests: injection-level selection test (mock path only, G2); the
   linking listener unit-tested with the mock auth stream.

**Done when:** staging build fetches real offerings (sandbox); simulated
path untouched for the gate; `paywall_debugger.dart` (exists in
`monetization`) usable in dev builds.

### M6.2 — Paywall on real offerings + restore + billing states

**Goal:** `feature_paywall` sells the real products and handles the ugly
states.

**Context.** `PaywallScreen` renders `offerings.current
.availablePackages` as bare `ListTile`s and has a working
"Restore purchases" button; with the simulated service, `getOfferings()`
returns null → empty list today. `PaywallStatus` lacks billing-problem
states.

**Steps**
1. UX pass on `PaywallScreen` with `core_ui` components: free-vs-pro
   comparison (collaborator cap 1 → 8 — source the numbers from
   `CollaboratorLimits`, don't hardcode), monthly/annual cards with
   `priceString`, restore, legal footnotes (links from M7.4).
2. Bloc: add `restoring`, `restored`, `noPurchasesFound` handling;
   surface store errors typed (user-cancelled ≠ failure toast — map
   RevenueCat `PurchasesErrorCode`s).
3. Grace/billing-retry: derive from `CustomerInfo` entitlement fields —
   show a non-blocking "billing issue" banner state (export a small
   `EntitlementStatus` from `monetization` so paywall/app don't touch
   `purchases_flutter` types directly; keeps G3 layering).
4. Empty-offerings guard: friendly "store unavailable" state (offline
   stores happen) rather than a blank list.
5. Tests: bloc tests over a fake service for every status; goldens for
   the new screen states; sandbox purchase happy-path checklist
   (**[HUMAN]** on both stores).

**Done when:** sandbox purchase upgrades caps live (invite sheet's
at-cap gate lifts without restart — `isProUserStream` already powers it);
restore works on a wiped install; **plan-M6 exit** "entitlement survives
reinstall" verified.

### M6.3 — Server-side entitlement enforcement

**Goal:** Caps gate **writes** server-side — a hacked client cannot
exceed the collaborator cap (plan decision 6).

**Steps**
1. RevenueCat webhook → HTTPS function `revenuecatWebhook` (verify the
   auth header): upsert `/entitlements/{uid} {pro, updatedAt, source}`.
2. M2.4 callables (`sendInvite`, `acceptInvite`, `acceptInviteToken`)
   read `/entitlements/{uid}` for the cap (`pro ? 8 : 1` — constants
   mirrored from `CollaboratorLimits` with cross-reference comments and a
   test pinning them equal… in both codebases).
3. Client keeps its `CollaboratorLimits` checks for UX (instant paywall
   gate), server is authoritative; typed at-cap error from callables maps
   to the existing `AtCap`/paywall flows.
4. Rules: `/entitlements` readable by self, writable by no client.
5. Tests: functions tests (webhook upsert, cap trip at 1 and 8); rules
   tests for the collection.

**Done when:** a raw callable invocation past the cap is rejected for a
free account on the emulator (webhook simulated); UX unchanged for honest
clients.

### M6.4 — Remote Config: package contract + Duet wiring

**Goal:** Pricing flags and kill-switches, testable and factory-shaped.

**Context.** `packages/services/remote_config` is one concrete
`RemoteConfigManager` (wraps `FirebaseRemoteConfig.instance`; keys
`show_paywall_on_onboarding`, `maintenance_mode`,
`min_supported_version`) with **no contract, no fake, wired into no app**.
Separately `app_updater` reads RC directly — two independent consumers
(M7.6 reconciles).

**Steps**
1. Refactor `remote_config`: abstract `RemoteConfigService` (typed
   getters + `init()` + a `refresh()`), `FirebaseRemoteConfigService`
   impl, `InMemoryRemoteConfigService` fake (constructor-seeded) —
   pattern-match `user_directory`'s contract/impl/fake split.
2. Duet keys (defaults committed in code): `paywall_enabled`,
   `invite_links_enabled` (kill-switches), `pricing_experiment` (string
   passthrough for offering selection), plus the existing three keys.
3. Injection: mock branch binds the seeded fake now; **[Track B]** the
   Firebase branch binds the real service (init after `initializeApp`,
   needs M0.2) (G2). Consumers pull via the contract only.
4. Wire one real use now (kill-switch: `invite_links_enabled == false`
   hides the link-share affordance in the invite sheet) so the plumbing
   is proven, not speculative.
5. Tests: fake-driven bloc/widget test of the kill-switch; contract unit
   tests.

**Done when (Track A):** the fake-driven kill-switch test proves the
plumbing and the contract refactor is complete; gate green; `showcase`
untouched or trivially updated. **(▸B):** flipping the flag in the
staging console (after fetch interval) hides link sharing.

**Landed (Track A).** `remote_config` refactored on `user_directory`'s
contract/impl/fake split: `RemoteConfigService` (typed getters + `init()`
+ `refresh()`; deliberately not `Result`-shaped — a failed fetch is never
a blocking error, the committed defaults just stay in effect),
`FirebaseRemoteConfigService` (what `RemoteConfigManager` did — that
class is gone; no other consumer existed), and a constructor-seeded
`InMemoryRemoteConfigService`. All six keys with committed defaults live
in `RemoteConfigKeys` (the three existing + `paywall_enabled` /
`invite_links_enabled` kill-switches defaulting **enabled** +
`pricing_experiment` string, default empty). Injection: **both** branches
of `configureDependencies` bind the in-memory fake for now — the real
service needs `Firebase.initializeApp` with real options (M0.2) and there
is no Remote Config emulator, so binding the fake under `useFirebase` too
keeps flag behavior defined instead of crashing (G2 holds; a
`TODO(track-b)` marks the swap point). Proven use: `showInviteSheetFor`
(`app.dart`) reads `inviteLinksEnabled` off the contract at open and
threads it into `showInviteSheet` as a `linkSharingEnabled` param — the
pairing feature never reads remote config itself (G3, same param seam as
its other deps); flag off hides the "Share invite link instead"
affordance + divider, email invites untouched. Tests: package unit tests
for both impls (defaults, overrides, fetch-failure swallow), fake-driven
widget tests of the kill-switch both ways, and an injection guardrail
test pinning `InMemoryRemoteConfigService` + enabled defaults.
`app_updater` still reads RC directly — untouched by design, reconciled
in M7.6. **The ▸B remainder stays in the Track B backlog:** bind
`FirebaseRemoteConfigService` under `useFirebase` once M0.2 lands real
options, then flip `invite_links_enabled` in the staging console and
watch the affordance disappear after the fetch interval.

---

## M7 — Observability & compliance

Covers plan M7: analytics + Crashlytics + perf traces (M7.1–M7.3), legal
compliance / consent / labels + GDPR export (M7.4, M7.5; deletion lives in
M1.8/M1.9), review_prompter + app_updater (M7.6). Can start any time
after M1, parallel with M3–M5. **Track note:** all six tasks are Track A
against fakes/the emulator; wherever a done-when below names a
staging/console/dashboard check, read it as that task's ▸B backlog item —
the code, contracts, and tests land now.

### M7.1 — New `crash_reporting` service package + wiring

**Goal:** Crash-free-rate visibility; the factory grows a first-class
crash package (plan: "no crash reporting package exists in the factory
yet").

**Context.** `packages/services/analytics`' `AppLogger` hard-couples
`FirebaseAnalytics` + `FirebaseCrashlytics` + `Talker` in one class —
don't extend that; disentangle.

**Steps**
1. `dart run tool/create_package.dart crash_reporting --layer services`
   (G5): contract `CrashReporter` (`recordError(error, stack, {fatal,
   context})`, `log(message)`, `setUserId(uid?)`), impls
   `CrashlyticsCrashReporter` + `NoopCrashReporter`.
2. Global hooks helper: `installCrashHooks(CrashReporter)` wiring
   `FlutterError.onError` + `PlatformDispatcher.instance.onError` — called
   from the real entry points only (mock/emulator get the noop; G2).
3. `setUserId` tied to the auth stream (uid only, no email); cleared on
   sign-out.
4. Refactor `AppLogger` to accept an injected `CrashReporter` instead of
   `FirebaseCrashlytics.instance` (keeps M7.2 clean); analytics package
   drops its direct crashlytics dep.
5. `flutterfire configure` re-run may be needed for the Crashlytics
   gradle plugin (**[HUMAN]** on merge day); document in the package
   README.

**Done when:** a forced test crash on staging appears in the console
dashboard; headless gate never touches Firebase (G2); package has fake-
driven unit tests.

**Landed (Track A).** `packages/services/crash_reporting`: `CrashReporter`
contract (`recordError(error, stack, {fatal, context})` / `log` /
`setUserId` — uid only, never email), `CrashlyticsCrashReporter`,
`NoopCrashReporter`, and `installCrashHooks(reporter)` chaining
`FlutterError.onError` (previous handler kept, so the console dump
survives) + `PlatformDispatcher.instance.onError`; fake- and
mocktail-driven unit tests for all three plus the hooks. `AppLogger`
(`packages/services/analytics`) now takes an injected `CrashReporter`
(defaults to the noop) and the analytics package dropped its direct
`firebase_crashlytics` dependency. Duet binds `NoopCrashReporter` in both
compositions (no Crashlytics emulator exists; a `TODO(M7.1-B)` in
`injection.dart` marks the real-entry-point binding) plus an eager
`CrashReporterUserBinder` (`lib/data/`, the `DirectoryPublisher` pattern)
forwarding the account stream's uid and clearing it on sign-out —
binder-tested, and the injection guardrail now pins the noop binding (G2).
The package README documents the ▸B/[HUMAN] `flutterfire configure`
re-run for the Crashlytics gradle plugin. **▸B remainder:** live
Crashlytics wiring + `installCrashHooks` in the real entry points (after
M0.2) and the forced-crash console check.

### M7.2 — Analytics: event catalogue + funnel instrumentation

**Goal:** The plan's named funnels emit real events: import, invite
sent/accepted, note recorded, practice opened — plus screen views.

**Context.** `analytics`' `AppLogger` is free-form (`logEvent(name,
params)`), wired into no app, no screen-tracking helper.

**Steps**
1. Duet-side typed catalogue `apps/duet/lib/data/duet_analytics.dart`
   (thin wrapper over `AppLogger` — the factory package stays generic):
   `sheetImported{pieceId}`, `inviteSent{method: email|link}`,
   `inviteAccepted{method}`, `noteRecorded{durationMs}`,
   `practiceOpened`, `paywallShown/`purchaseCompleted` (M6 hooks),
   `signUp`. No PII in params (emails never).
2. Instrument at the seams the research pinned: `ImportPieceBloc` submit
   success; `InviteBloc`/`DefaultCollaboratorInviteService` send;
   accept paths (M2.4 client glue); `_saveAudioNote` success
   (score_viewer_screen.dart); practice-view open; paywall bloc.
   Prefer app-glue/bloc-listener instrumentation over embedding analytics
   deps in feature packages (G3 layering — features stay
   analytics-free; wire via callbacks or a bloc observer where needed —
   decide once, document in the wrapper's doc comment).
3. Screen views: a `GoRouter` observer in `app.dart` logging route names.
4. Injection: real `AppLogger` in Firebase branch; a no-op/`Talker`-only
   logger in mock branch (G2).
5. Tests: fake-logger asserting each funnel call site fires exactly once
   per action (extend existing bloc tests).

**Done when:** DebugView on a staging device shows the five funnel events
end-to-end; dashboards seeded (**[HUMAN]**: mark conversion events in the
console); gate green.

**Landed (Track A).** `apps/duet/lib/data/duet_analytics.dart`: the typed
catalogue (`sheetImported{pieceId}` / `inviteSent{method}` /
`inviteAccepted{method}` / `noteRecorded{durationMs}` / `practiceOpened` /
`paywallShown` / `purchaseCompleted` / `signUp` / `screenViewed`), no PII
in params. Instrumentation decided once (documented on the wrapper):
feature code stays analytics-free (G3) — one app-level
`DuetAnalyticsObserver` (`Bloc.observer`, set in `injection.dart`) maps
bloc/cubit transitions to events (import success; invite sent email+link;
BOTH accept paths — M5.6 inbox accept = email, M5.2 token accept = link;
`AudioNoteSaved` = the `_saveAudioNote` success dispatch; the
practice-intent region resolve; paywall gates; purchase-not-restore;
sign-up-not-login), plus a `DuetRouteObserver` on the `GoRouter` logging
route-template screen views and the `/paywall` route's `paywallShown`.
`AppLogger` gained a Firebase-free default (no analytics instance =
Talker-only); both Duet compositions bind it with the injected
`CrashReporter` — `FirebaseAnalytics.instance` needs a real
`initializeApp`, so the real binding is a `TODO(track-b)` in
`injection.dart`, the M6.4/M7.1 precedent — and the injection guardrail
pins the Firebase-free binding (G2). Fake-logger tests assert every
funnel call site fires exactly once per action against the real blocs.
**▸B remainder:** bind `FirebaseAnalytics.instance` under the real entry
point (after M0.2), DebugView end-to-end check, console dashboards +
conversion marking.

### M7.3 — Performance traces on the two hot paths

**Goal:** PDF open and page render report real timings (plan M7 bullet).

**Steps**
1. Add `firebase_performance` to Duet; write a decorator
   `TracedPdfRenderService implements PdfRenderService` (in app glue or a
   tiny `pdf_rendering` add-on kept Firebase-free — decorator lives
   app-side) wrapping `open()` (`trace: pdf_open`, attrs: page count,
   byte size bucket) and `renderPage()` (`trace: pdf_render_page`, attrs:
   scale) — the contract's two hot methods.
2. Injection: wrap only in the Firebase branch (G2).
3. Manual screen-trace for reader open→first-canvas (the composite user
   moment): start in `DuetScorePage.initState`, stop on first ready frame.
4. Verify overhead is negligible (traces are sampled; no sync work added
   on the render path).

**Done when:** staging dashboard shows both traces with sane numbers; M8.2
uses them as its before/after metric.

### M7.4 — Legal surfaces: privacy policy, ToS, consent, store data maps

**Goal:** The compliance surface area exists and matches what the app
actually collects.

**Steps**
1. **[HUMAN]** Author + host privacy policy and ToS (hosting site is fine
   — `hosting/` from M0.4); provide URLs.
2. Add `legal_compliance` wiring (dep added in M1.9): Settings "About"
   group — `PrivacyPolicyButton` + ToS link + version row.
3. Consent: per the Open decision, default to a minimal in-house consent
   record (timestamped acceptance of ToS/policy at sign-up, stored with
   the account) — implement `ConsentService` (the package ships only the
   abstract contract) with a Firestore-backed impl; show acceptance
   checkbox on sign-up (M1.2's screen gains it). If ads/tracking SDKs
   ever land, revisit with a real CMP.
4. Data map: `docs/duet_privacy_data_map.md` — enumerate collected data
   from the schema (email, display name, device tokens, ink strokes,
   audio recordings, PDFs, purchase state, analytics events) with
   purpose/retention; **[HUMAN]** transcribe into App Privacy labels +
   Play Data Safety forms (M9.4 blocks on this).
5. Tests: settings rows render; consent recorded on sign-up (fake
   service).

**Done when:** policy/ToS reachable in-app; consent recorded server-side;
data-map doc merged and store forms drafted.

### M7.5 — GDPR self-service data export

**Goal:** A user can download everything Duet holds about them
(deletion already ships via M1.8/M1.9).

**Steps**
1. Callable `exportMyData`: gathers auth profile, directory entry,
   pieces owned/collaborating (metadata), own layers/notes JSON, list of
   own audio assets + short-lived signed URLs, entitlement state →
   writes a JSON bundle to a private Storage path → returns a signed URL
   (24 h).
2. Settings: "Download my data" row → progress → share-sheet the URL
   (or open in browser).
3. Rate-limit: once per day per uid (reuse M2.5's limiter pattern).
4. Tests: functions test asserting the export contains exactly-and-only
   the caller's data (two-user fixture).

**Done when:** emulator export for user A contains A's notes and none of
B's; Settings flow works on staging.

### M7.6 — `review_prompter` + `app_updater` wiring

**Goal:** The two remaining factory packages go live (plan M7 bullet 3).

**Context.** `ReviewPrompter` (concrete, `in_app_review` +
`SharedPreferences`): `incrementAppOpenCount()` at startup +
`logCoreActionCompleted()`; prompts once when opens ≥ 5 ∧ a core action
happened. `AppUpdateService`/`ForceUpdateWidget` read RC keys
`min_supported_version` + `store_url` **directly** via
`FirebaseRemoteConfig.instance`.

**Steps**
1. Add both packages to Duet. `incrementAppOpenCount()` in the real entry
   points; `logCoreActionCompleted()` exactly at the "saved a note" happy
   moment — alongside the M7.2 `noteRecorded` hook in `_saveAudioNote`'s
   success path (app glue, not inside feature_score).
2. Refactor `app_updater` to consume M6.4's `RemoteConfigService`
   contract instead of its own RC instance (one config pipeline; fake-
   testable); wrap Duet's app root in `ForceUpdateWidget` (Firebase
   entries only — mock boot skips it, G2).
3. Populate RC: `min_supported_version` (start `0.0.0`), `store_url`
   (per-platform once store listings exist — placeholder until M9.4).
4. Tests: prompter triggers once at the threshold (fake prefs + fake
   in_app_review); force-update gate renders below-min (fake RC).

**Done when:** simulated below-min version blocks with the update screen;
review prompt fires on the 5th open after saving a note (manual staging
check); gate green.

**Landed (Track A).** `app_updater` refactored onto M6.4's
`RemoteConfigService` contract (its own `firebase_remote_config` dep
dropped — nothing else in the package needed it): `AppUpdateService` now
takes a `RemoteConfigService` (required) plus an injectable
`currentVersion` seam (defaults to `package_info_plus`), reads
`min_supported_version`/`store_url` off the contract, and fails open on
an empty min, a swallowed refresh, or an unreadable current version.
`store_url` was the one missing key — added to `RemoteConfigKeys` (default
`''`, placeholder until store listings exist, M9.4) with getters on both
the in-memory and Firebase impls (G3, all impls + the guardrail widened in
one PR). `ForceUpdateWidget`'s service is now required (no
`FirebaseRemoteConfig.instance` fallback). Duet wiring: both packages are
path deps; `injection.dart` registers `AppUpdateService` over the bound
`RemoteConfigService` (lazy) and `ReviewPrompter` via a lazy-async
`ReviewPrompter.create` (new factory — construction touches the
SharedPreferences platform channel, so nothing on the headless gate ever
resolves it; the M7.1 keep-platform-channels-behind-a-seam precedent, G2).
`main.dart`/`main_emulator.dart` fire `incrementAppOpenCount()` after
`configureDependencies` (fire-and-forget, real entries only — the gate
never runs `main`); `app.dart`'s `MaterialApp.router` `builder` wraps every
routed screen in `ForceUpdateWidget` fed the injected service (fails open —
the mock composition's `min_supported_version: 0.0.0` can never block, G2).
The "saved a note" core-action moment rides a new `onNoteSaved` callback on
`ScoreViewerScreen` (fired in `_saveAudioNote`'s success path, beside the
existing snackbar) that `DuetScorePage` maps to
`ReviewPrompter.logCoreActionCompleted()` — app glue, no `review_prompter`
import inside `feature_score` (architecture-test clean). Tests:
`app_updater` unit tests seed an `InMemoryRemoteConfigService` (no more
Firebase fake) plus two widget tests (blocks below-min, renders child
at/above); `review_prompter` gains an end-to-end fake-prefs test proving
the prompt fires exactly once at the 5-open ∧ core-action threshold and
never again; the injection guardrail pins the never-block gate + the lazy
prompter registration; the deep-link redirect harness registers both new
services (fixed `currentVersion` so the widget-test binding's absent
`package_info` channel can't hang `pumpAndSettle`). Gate: `analyze` +
`test` green across `app_updater`, `review_prompter`, `remote_config`, and
`apps/duet` (goldens excluded as usual). **The ▸B remainder stays in the
Track B backlog:** real RC values in the staging console
(`min_supported_version` bump + per-platform `store_url`) once
`FirebaseRemoteConfigService` is bound under `useFirebase` (M0.2), then the
manual staging check — a below-min build shows the update screen and the
review prompt fires on the 5th open after a saved note.

---

## M8 — Performance, resilience, device QA

Covers plan M8: thumbnails (M8.1), large-PDF memory (M8.2), audio caps
(M8.3), failure-mode audit (M8.4), device-matrix + a11y + l10n decision
(M8.5). The hardening pass after M4/M5; M8.1/M8.3 have no cloud
dependency and can start anytime.

### M8.1 — Real page thumbnails in the reader rail

**Goal:** Close the standing TODO — the rail shows the actual pages.

**Context.** `score_viewer_screen.dart` (~L668) carries
`TODO(reader-redesign): render real PDF thumbnails once a cheap per-page
thumbnail render path exists`; `PageThumbnailRail`'s `_PageThumb` draws a
stylized fake card. `PdfRenderService` has `renderPage(pageIndex,
{scale})` (full-page, default 2×) and **no cache**; `PdfPageImage` is raw
RGBA bytes.

**Steps**
1. `pdf_rendering`: add `renderThumbnail(int pageIndex, {int maxWidth =
   96})` to the contract (implemented in `PdfrxRenderService` as a
   low-scale render; compute scale from page width) — update fakes
   (`FakePdfRenderService` in the duet harness, `_StaffPaperRenderService`
   in `main_screenshot.dart`).
2. `ThumbnailCache` (feature-side or app glue): LRU of decoded
   `ui.Image`s keyed `(checksum, pageIndex)`, capped (~40 thumbs);
   optional disk layer under the M3.4 cache dir keyed the same way
   (`PdfRenderService.checksum`'s doc already anticipates keying cached
   renders).
3. `PageThumbnailRail`: render the real thumb with the stylized card as
   loading placeholder; keep ink/audio presence dots and all semantics
   (`PageInkPresence` unchanged).
4. Update goldens (`page_thumbnail_rail_golden_test.dart`) with a
   deterministic fake render; keep 48×48 tap-target tests green.

**Done when:** rail shows real pages on device; TODO comment deleted;
goldens/tests green.

**Landed.** `PdfRenderService.renderThumbnail(pageIndex, {maxWidth = 96})`
joined the contract; `PdfrxRenderService` implements it as a low-scale
render (scale = `min(1, maxWidth / page.width)`, sharing `renderPage`'s
body), and every fake/impl was widened in the same PR (G3): the duet
harness `FakePdfRenderService`, `main_screenshot.dart`'s
`_StaffPaperRenderService`, and the four test fakes. New
`apps/duet/lib/features/score/src/thumbnail_cache.dart`: an LRU of
decoded `ui.Image`s keyed `(basePdfChecksum, pageIndex)`, capped at 40,
disposing evicted images; callers receive *clones* they own, so eviction
can never invalidate an image a widget is still drawing; in-flight
renders dedupe; failures resolve `null` and are never cached (disk layer
skipped — not trivial). `PageThumbnailRail` gained an optional
`thumbnailFor` seam; the old stylized card is now the loading/unavailable
placeholder, and `_ThumbImage` owns + disposes each image (dropping late
arrivals for unmounted/recycled cards). `ScoreViewerScreen` owns one
cache per screen (disposed with it) and wires the seam after `open()`
succeeds; the `TODO(reader-redesign)` is gone. `PageInkPresence`,
presence dots, semantics, and the 48×48 tap targets are unchanged
(covered by new widget tests incl. a real-thumbnail tap-target check);
`thumbnail_cache_test.dart` covers hit/miss, LRU eviction + recency,
clone safety, dedupe, and failure retry. The rail golden now renders
deterministic fake pages (raw-RGBA bands, decoded under
`tester.runAsync` — no fonts/platform channels); its two PNGs were
regenerated on a macOS host that carries the known sub-pixel font drift
vs. the canonical Linux container, so CI should re-validate (re-update)
just `page_thumbnail_rail*.png` there. Device check (real PDF on iPad)
pending as the task's visual verification.

### M8.2 — Large-PDF memory strategy

**Goal:** A 60-page scan doesn't OOM an older iPad: page eviction +
render-scale-by-zoom.

**Context.** `ScorePageCanvas` renders full pages at a **fixed 2×**,
decodes via `decodeImageFromPixels`, no cache — every page flip
re-renders; `InteractiveViewer` zooms 0.5–6× over the fixed-scale image;
`PdfrxRenderService` holds one open document and disposes source bitmaps
immediately.

**Steps**
1. Page-image LRU (current ± 1 page warm, hard cap ~3 decoded images) in
   an app/feature-level `PageImageCache`; `ScorePageCanvas` consumes it
   instead of private futures; dispose evicted `ui.Image`s.
2. Render scale by zoom: base render at a scale fitted to the viewport
   (not fixed 2×); on zoom past ~1.5× of base, re-render the page at a
   higher scale (debounced), swap in place; cap max scale by page pixel
   budget (e.g. ≤ 16 MP per image).
3. Prefetch next/prev page on idle (post-frame, cancellable on page
   change).
4. Measure: use the M7.3 traces + `flutter run --profile` on the lowest-
   end target device; record budgets (open < 2 s for a 20 MB PDF, page
   flip < 300 ms warm, memory < 400 MB on the 60-page scan) in
   `docs/duet_perf_budgets.md` with actuals (**plan-M8 exit** asks for
   measured budgets on a low-end device — [HUMAN] runs the device
   profile).
5. Tests: cache eviction unit tests; existing reader widget/golden tests
   green (rendering path changes must not alter visuals at default zoom).

**Done when:** budgets doc has real numbers meeting targets (or filed
exceptions); no regression in reader tests.

### M8.3 — Audio note size caps + compression

**Goal:** Notes stay small and uploads predictable.

**Context.** Duration is capped (60 s in `RecordAudioCubit.maxDuration`,
65 s service backstop) but **no byte cap or encoder config exists** —
`RecorderPort` uses a default `RecordConfig()`; files are `.m4a`;
`LocalAudioAssetStore.put` blind-copies; M2.2 storage rules cap audio at
5 MB.

**Steps**
1. `RecordAudioRecorderService`/`PackageRecorderPort`: explicit
   `RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000,
   sampleRate: 44100, numChannels: 1)` — voice-quality mono ≈ 0.5 MB/min,
   comfortably under the rules cap.
2. `AudioAssetStore.put` enforces a byte cap (constant shared with the
   storage rule — cross-reference comment): over-cap →
   `ResultFailure` surfaced per G4 ("Recording too large") — should be
   unreachable with the encoder settings; it's the honest backstop.
3. Record the format decision in the M2.1 schema doc (content-type
   `audio/mp4`).
4. Tests: recorder config unit test; over-cap put failure test; existing
   `record_audio_cubit_test.dart` (60 s cap) stays green.

**Done when:** a max-length note lands ≈ ≤ 1 MB on the emulator; caps
enforced client + rules side; gate green.

**Landed.** **Encoder.** `RecordAudioRecorderService.recordConfig` — a
static const `RecordConfig(encoder: aacLc, bitRate: 64000, sampleRate:
44100, numChannels: 1)` (AAC-LC mono ≈ 0.5 MB/min; defaults-matching
values deliberately re-stated and lint-ignored, pinning against upstream
drift) — now passed on every `start`. **Byte cap.** `maxAudioNoteBytes`
(5 MB) + `AudioNoteTooLargeException` + a shared `ensureAudioNoteWithinCap`
guard live beside the `AudioAssetStore` contract
(`apps/duet/lib/domain/src/domain/audio_asset_store.dart`), cross-referenced
comment-to-comment with the `storage.rules` audio rule; every `put` applies
it — `LocalAudioAssetStore`, `CloudAudioAssetStore` (rejects *before*
caching/enqueueing so an over-cap file never sits in the upload queue), and
the in-memory fakes (flow harness, screenshot harness, migrator +
review-sync test fakes) for G3 parity. **Surfacing.** `_saveAudioNote` in
`score_viewer_screen.dart` treats `AudioNoteTooLargeException` as a hard
stop — "Recording too large" via `AppSnackbar.error`, note not saved —
instead of the raw-path fallback (which would have smuggled the file past
the rules cap). **Format decision** recorded in `duet_cloud_schema.md`
(Storage section): `.m4a`/MPEG-4, content-type `audio/mp4`, now set
explicitly by `FirebaseAudioObjectStore.upload` via `SettableMetadata` (the
extensionless object name infers nothing). **Tests.** Recorder-config
assertion (`record_audio_recorder_service_test.dart`); over-cap +
just-under-cap `put` tests (local store); over-cap nothing-cached /
nothing-enqueued test (cloud store); the 60 s-cap
`record_audio_cubit_test.dart` untouched and green. Also fixed en route:
three pre-existing lint findings from the `main_emulator_driver.dart` dev
entrypoint (package import, documented `depend_on_referenced_packages`
ignore, dev_dependency sorting).

### M8.4 — Failure-mode audit: quota, interrupted uploads, rules-denied

**Goal:** Every cloud failure surfaces as honest UI through the existing
`Result` plumbing — no silent data loss, no raw error dumps (plan M8
bullet 2).

**Steps**
1. Enumerate + reproduce on the emulator (checklist doc
   `docs/duet_failure_modes.md`): Storage quota exceeded / upload
   interrupted mid-import (kill app; resume path from M3.3's
   `basePdfUploaded` repair) / rules-denied write (stale client after
   collaborator removal — repo maps to `OwnershipViolation`) / offline
   invite send / callable deadline / expired-token accept / audio queue
   poison entry (permanently failing upload → surfaced, skippable).
2. For each: assert the surfaced UX (which of `ErrorRetryView` /
   `AppSnackbar.error` / bloc failure state per G4) and fix the gaps —
   the audit *is* the work; expect fixes in `ImportPieceBloc`,
   `ScoreBloc` error paths, the upload queue, and `AcceptInviteCubit`.
3. Add regression tests per fixed gap (fake repos scripting the
   failure).
4. Mark the checklist complete with links to tests — **plan-M8 exit**
   artifact.

**Done when:** checklist merged with every row green/linked; no failure
mode ends in a spinner or silence.

### M8.5 — Device-matrix QA, accessibility pass, localization decision

**Goal:** The plan's QA sweep, mostly human-executed with agent fixes.

**Steps**
1. **[HUMAN]** Device matrix: iPad landscape (design target), small
   phone (<600dp — `columnsForWidth` breakpoints and all reader flows),
   large phone, tablet portrait. Log issues; agent fixes batched.
2. Accessibility: semantics coverage is strong (feature_score's
   `Semantics`/`ExcludeSemantics` convention) — verify **contrast**
   (dark Stage reader vs. WCAG AA for text/pills) and **dynamic type**
   (200% text on Settings/library/paywall; reader chrome may pin with a
   documented rationale). Fix violations; add a contrast check note to
   `core_theme` if tokens change.
3. Localization decision (Open decisions): default English-only 1.0 —
   if confirmed, sweep for hardcoded strings into a single strings file
   per package only where trivial (no full l10n framework); if Hebrew
   enters 1.0, spin a dedicated task series (RTL audit of the reader is
   substantial — canvas gestures, rails, popovers).
4. Tests: any fixed widget gets a regression test; goldens for contrast-
   driven token changes.

**Done when:** matrix checklist complete; a11y violations fixed or
waived-with-rationale; l10n decision recorded in this doc's decisions
table.

---

## M9 — Release engineering & launch

Covers plan M9: CI/CD gate + store lanes (M9.1, M9.2), screenshot
automation (M9.3), store readiness incl. review notes + demo account
(M9.H, M9.4), launch runbook + staged rollout (M9.5). **Track note:**
M9.1 is Track A (all its inputs are emulator-based); the rest is Track B.

### M9.1 — CI: the full PR gate

**Goal:** One required PR gate: melos gate + rules tests + emulator E2E
(plan M9 bullet 1) — mostly assembling prior tasks.

**Track A.** Every input is emulator-based. While M0.5 stays deferred,
include its PR-side functions build/test job here.

**Steps**
1. `ci.yaml`: ensure jobs = analyze-and-test (existing), goldens
   (consider making it required now the suite is stable — decide and
   document), rules-tests (M1.7/M2.3), emulator-e2e (M4.5),
   functions build/test (M0.5). Path-filter the expensive jobs; all
   required on `master` PRs.
2. Concurrency groups + caches (pub, gradle, firebase emulators, npm) to
   keep the wall-clock sane (< ~15 min target).
3. Branch protection updated (**[HUMAN]** repo settings).

**Done when:** a PR touching `apps/duet` runs the full gate; required
checks block merge; wall-clock recorded in the workflow file header.

### M9.H — [HUMAN] Signing + store presence

- Apple: distribution cert, App Store Connect app records (staging via
  TestFlight only), App Store Connect API key for CI.
- Google: Play Console app, service-account JSON for CI upload, internal
  track.
- Store listings drafted (name, subtitle, description, keywords,
  category, age rating).
- Seeded **prod demo account** for App Review (works with M9.4's notes;
  seed a piece with annotations so reviewers see the core loop).

### M9.2 — Tagged builds → TestFlight / Play internal

**Goal:** `v*` tags produce signed, uploaded builds per flavor.

**Context.** `deploy_apps.yaml` already builds unsigned
IPA/appbundle matrices on changed apps (with M0.5's fixes). Platform
priority decision: iOS-first — Android lane can trail one milestone.

**Steps**
1. Extend/replace `deploy_apps.yaml`: on tag `duet-v*` → build
   `--flavor prod -t lib/main.dart` (+ staging lane on `duet-staging-*`
   tags), sign with M9.H secrets (fastlane or raw `xcodebuild`/gradle +
   `pilot`/Play publisher — prefer fastlane, committed under
   `apps/duet/fastlane/`).
2. Version stamping: tag drives `--build-name/--build-number`.
3. Upload: TestFlight (App Store Connect API key) + Play internal track.
4. Document the release cut in `docs/duet_release.md` (tag → wait for
   lanes → promote).

**Done when:** a staging tag lands a build installable via
TestFlight/internal track without manual Xcode/Studio steps.

### M9.3 — Store screenshot automation

**Goal:** Reusable store screenshots from the existing harness (plan:
"can reuse `main_screenshot.dart`").

**Steps**
1. Extend `apps/duet/lib/main_screenshot.dart`'s harness scenes to the
   store shot-list (library with sheets, reader with two ink colors +
   audio pin, invite sheet, paywall) — it already fakes repos/renderers
   and needs no Firebase.
2. Drive with the `screenshot` skill's Playwright flow at store
   resolutions (6.7", 6.1", 12.9" iPad; Play phone/tablet), output to
   `docs/screenshots/store/` (git-lfs not needed; keep count small).
3. Script it: `tool/store_screenshots.sh` so re-runs are one command.
4. **[HUMAN]** Pick/frame finals in the store consoles.

**Done when:** one command regenerates the full shot-list deterministically.

### M9.4 — App Review readiness pack

**Goal:** Pass review first try (plan: Apple tests account deletion and
Sign in with Apple).

**Steps**
1. Verify the two Apple hard requirements end-to-end on a prod build:
   in-app account deletion (M1.9) and Sign in with Apple working +
   offered wherever Google is (login screen already renders
   `SignInWithAppleButton`).
2. App Review notes: demo account credentials (M9.H), how to see
   collaboration (pre-seeded second account's shared piece), note that
   invites/push need a second account.
3. Privacy labels / Data safety forms submitted from
   `docs/duet_privacy_data_map.md` (M7.4) (**[HUMAN]** console forms).
4. Permission prompt strings audit: mic (recording), notifications,
   photo/file access via file_picker — purpose strings in Info.plist
   reviewed (App Review rejects vague ones).
5. Pre-submission checklist committed to `docs/duet_release.md`.

**Done when:** checklist complete on a prod TestFlight build; submission
package ready.

### M9.5 — Launch runbook

**Goal:** Boring launch: staged rollout with tripwires and rollback paths
(plan M9 bullet 3).

**Steps**
1. `docs/duet_launch_runbook.md`:
   - Staged rollout: Play staged 10% → 50% → 100%; iOS phased release on.
   - Gates between stages: Crashlytics crash-free ≥ 99.5%, no new
     top-crash, funnel sanity (M7.2 dashboards).
   - Rules rollback: redeploy previous git revision via M0.5 pipeline
     (exact commands); Functions rollback likewise.
   - Alerts (**[HUMAN]** console): Functions error-rate + p95 latency,
     Firestore/Storage cost anomalies (budget alerts from M0.H),
     Crashlytics velocity alerts.
   - On-call notes: known failure modes link (M8.4 doc), support-email
     triage, kill-switches available (M6.4 flags).
2. Dry-run the rollback commands against staging once; record output.

**Done when:** runbook merged; rollback dry-run evidenced; staged rollout
of 1.0 can proceed — **plan-M9 exit**.

---

## Post-launch backlog (unchanged from the plan — out of 1.0)

Presence/live cursors · OMR-lite passage labels · versioned annotation
history · teacher/student roles (`user_roles` package exists, unwired) ·
practice tools (metronome, tuner) · web reader.

## Coverage notes (plan → tasks)

- Every M0–M9 plan bullet maps to at least one task above; two items the
  plan implies but never names got explicit tasks: the in-app invite
  inbox UI (M5.6 — email invitees currently have no way to accept) and
  the piece-`updatedAt` bump on annotation writes (inside M3.7 — without
  it unread dots never fire).
- Two plan overstatements corrected by the codebase: `DeepLinkInviteService`
  models but does **not** enforce expiry (M5.2 closes it), and invite
  *acceptance* needs server authorization once pieces rules land — pulled
  forward into M2.4 so M3's E2E isn't blocked.
- The plan's sequencing holds at task level: M0 → M1 → M2 → M3 → {M4, M5}
  → M8 → M9, with M6/M7 parallel after M1 (M6.3 additionally needs M2.4).
- Re-cut (same day): tasks regrouped into **Track A (emulator-first)** and
  **Track B (name-gated)** to defer all real-Firebase setup until the
  product name is decided. Task IDs and bodies are unchanged apart from
  track annotations; Track A's entry point is M0.4 (was M0.H). The
  `demo-*` emulator project-id convention guarantees Track A can never
  touch a real Firebase resource.
