# Duet — Production Readiness Plan (Firebase-backed)

A milestone plan for taking Duet from its current state to a production,
Firebase-backed release. Planning document only — each milestone is intended
to become its own green PR (or a small series), driven through the factory's
agent pipeline (product-manager → architect → flutter-builder → qa-engineer →
code-reviewer).

## Where the app is today

Grounded in the codebase as of this writing:

**Already built and Firebase-ready**

- Identity, email-directory, device-token, and invite-inbox seams have real
  Firestore implementations (`FirebaseAuthRepository`, `FirestoreUserDirectory`,
  `FirestoreUserMessaging`) behind swappable contracts, selected by
  `configureDependencies(useFirebase: …)` in `apps/duet/lib/injection.dart`.
- Firestore rules exist for those collections (`apps/duet/firestore.rules`),
  with two explicitly documented v1 accepted risks (inbox spam,
  un-rate-limited directory lookups) marked as pre-prod gates.
- A full local Firebase Emulator Suite workflow (`main_emulator.dart`,
  `firebase.json`, the `duet-emulator` / `duet-device` skills) and
  emulator-backed collaborator E2E tests.

**Not production-ready yet**

- **No production Firebase project**: `main.dart` boots fully mocked; only the
  emulator entry point initializes Firebase (with a throwaway app id). No
  `firebase_options.dart`, no flavors, no App Check.
- **Pieces, ink, audio notes, and PDFs are local-only**
  (`LocalPieceRepository` / `LocalAnnotationRepository` /
  `LocalAudioAssetStore` over `local_storage` + app documents). Cross-device
  collaboration is a manual `.duet` bundle export/import (`review_sync`); the
  reader's sync badge is session-local by design.
- Push has no server-side sender (no Cloud Functions anywhere); invites
  surface via a foreground inbox bridge only.
- `MonetizationService` is simulated; deep links are `FakeDeepLinkService`.
- Factory packages not yet wired into Duet: `analytics`, `remote_config`,
  `app_updater`, `legal_compliance`, `review_prompter`. No crash reporting
  package exists in the factory yet.

## Architecture decisions (locked up front — they shape every milestone)

1. **Firestore becomes the source of truth for pieces + annotations; Cloud
   Storage holds binaries** (PDFs keyed by checksum, audio notes by asset id).
   The existing `PieceRepository` / `AnnotationRepository` / `AudioAssetStore`
   contracts are the swap seam; blocs and UI don't change. Per-author ink
   layers are already conflict-free by construction (each participant writes
   only their own layer), which makes live sync cheap to get right.
2. **Offline-first**: Firestore offline persistence for metadata/annotations,
   plus a local binary cache keyed by checksum (today's local repositories
   become the cache layer, not dead code). A musician on stage without Wi-Fi
   must still open their sheets.
3. **`review_sync` bundles get demoted, not deleted** — kept as the
   airplane-mode escape hatch, removed from the primary reader UI.
4. **Invite links on a custom domain** with App Links / Universal Links
   (Firebase Dynamic Links is sunset — nothing new gets built on it), using
   the single-use, expiring token-doc flow `DeepLinkInviteService` already
   models.
5. **Three Firebase projects** — `duet-dev` (emulator-first), `duet-staging`,
   `duet-prod` — matched by Flutter flavors. Blaze plan (Functions + Storage
   require it) with budget alerts from day one.
6. **Server-authoritative writes where trust matters**: invite delivery, push
   fan-out, entitlement-gated caps, and account-deletion purge move behind
   Cloud Functions (closing the rules file's documented v1 risks).

---

## M0 — Firebase foundations & environments

*Everything else depends on this.*

- Create the three Firebase projects; `flutterfire configure` per flavor →
  `firebase_options_{dev,staging,prod}.dart`; real bundle ids; Android/iOS
  flavors and entry points (`main.dart` becomes the prod Firebase entry;
  today's mock boot moves to `main_mock.dart` for the headless test gate;
  `main_emulator.dart` stays).
- App Check (Play Integrity / DeviceCheck) in monitoring mode; regions pinned
  for Firestore/Storage/Functions; budget alerts + usage dashboards.
- CI service-account secrets; `firebase deploy` targets for rules, indexes,
  and functions in-repo (`firebase.json` grows Storage/Functions/hosting).

**Exit:** staging app signs in with the real `FirebaseAuthRepository` on a
device; the headless test gate still runs fully mocked and green.

## M1 — Identity & account lifecycle

- Harden `feature_auth`: sign-up, password reset, email verification (the
  contract today covers login / Google / Apple / logout), an error taxonomy
  surfaced through the existing `Result` pattern, re-authentication for
  sensitive operations.
- **Account deletion** (App Store hard requirement) with full data purge
  fan-out (owned pieces, authored layers/notes, directory entry, device
  tokens, storage objects) — a Cloud Function, since clients cannot delete
  cross-user data.
- Profile: display-name editing propagating to `usersByEmail` (the upsert
  listener already exists in `injection.dart`) and a `discoverable` toggle in
  Settings (the rules already support the flag).

**Exit:** full auth lifecycle E2E against the emulator (extends
`collaborator_flow_test`); `usersByEmail` rules tests in CI.

## M2 — Cloud schema + security rules for pieces

*Design before code.*

- Firestore schema: `/pieces/{id}` (metadata + `participantIds` for
  array-contains queries), `/pieces/{id}/layers/{uid}` (one doc per author's
  ink, matching `ParticipantLayer`), `/pieces/{id}/notes/{noteId}`. Storage:
  `/pieces/{id}/base.pdf`, `/pieces/{id}/audio/{assetId}`.
- Rules: owner-vs-collaborator ACL (owner deletes the piece / removes
  collaborators; authors mutate only their own layer and notes — mirroring
  the ownership guards `LocalAnnotationRepository` enforces client-side
  today). Storage rules mirror piece membership. Composite index plan
  committed as `firestore.indexes.json`.
- Close the two documented v1 rule risks: inbox `create` moves behind a
  Function; directory lookups get App Check enforcement + rate limiting.

**Exit:** emulator rules-test suite green in CI — before any client code
writes to these collections.

## M3 — Cloud-backed pieces (the big migration)

- Implement `FirestorePieceRepository`, `FirestoreAnnotationRepository`, and
  `CloudAudioAssetStore` behind the existing contracts. Import uploads the
  PDF (checksum dedupe — `Piece.basePdfChecksum` already exists) with
  progress UI; a binary download/cache manager for offline reading; an
  upload queue for audio notes recorded offline.
- One-time migration: on first cloud sign-in, offer to upload existing local
  pieces (the local repositories already hold everything needed).
- Gallery (`feature_library`) reads live queries: "My sheets" (owner) and
  "Shared with me" (collaborator) shelves become real; unread dots get a real
  signal (last-opened timestamp vs. content updates).

**Exit:** two emulator accounts see the same piece, ink, and audio pins live;
offline edit → reconnect converges; emulator E2E covers the loop.

## M4 — Live collaboration in the reader

*Cashes in the reader UI/UX work (PR #50).*

- `ScoreSyncStatus` stops being session-local: wired to real repository state
  (pending writes / connectivity). The top-bar badge and Layers-panel prompt
  already render it.
- Share/Import bundle affordances leave the reader's primary UI;
  `onShareRequested` becomes "nudge collaborator"; the save-note snackbar's
  "Share now" sends the push nudge.
- Collaborator attention loop: per-layer new-annotation markers since last
  read; the audio-pin "new" state.
- Cross-device delete/edit semantics for notes (soft-delete tombstones so an
  offline peer converges).

**Exit:** two physical devices on staging annotate the same sheet in real
time; the reader E2E suite runs against the emulator in CI.

## M5 — Invites, deep links, push (closing the loop)

- Real `DeepLinkService` (replace `FakeDeepLinkService`): `app_links` +
  Universal Links/App Links on a custom domain with a small hosted fallback
  page; invite tokens as single-use, expiring Firestore docs.
- Cloud Functions v2: `onInviteCreated` → FCM to the invitee's tokens (via
  the existing `deviceTokens` registry + `DeviceTokenSync`),
  `onAnnotationsChanged` → batched digest push ("Maya added 3 notes to Clair
  de Lune"), token pruning on `UNREGISTERED`, and the M2 inbox-write
  authorization.
- Notification tap-through routing to the exact piece (go_router deep-link
  paths exist under `apps/duet/lib/routing/`).

**Exit:** invite → push → tap → the sheet opens, demonstrated on two physical
devices against staging; `duet-device` skill updated.

## M6 — Monetization for real

- Replace `SimulatedMonetizationService` behind the `MonetizationService`
  contract. **Recommendation: RevenueCat** (server-side receipt validation,
  entitlements, no bespoke backend). Products: free tier (current collaborator
  cap; piece cap TBD) vs. premium.
- `feature_paywall` wired to real offerings; restore purchases; grace /
  billing-retry states. Entitlement checks become server-side where they gate
  writes (collaborator cap enforced in rules/Functions, not just the client).
- Remote Config (`remote_config` package) for pricing flags and
  feature kill-switches.

**Exit:** sandbox purchases upgrade caps live on both stores; entitlement
survives reinstall.

## M7 — Observability & compliance

- Wire the factory packages Duet doesn't use yet: `analytics` (screen +
  funnel events: import, invite sent/accepted, note recorded, practice
  opened); **add a Crashlytics service package** (factory-style, new);
  performance traces on the two hot paths (PDF open, page render).
- `legal_compliance`: privacy policy + ToS surfaces, consent where required;
  self-service data export & deletion (GDPR); App Privacy labels / Play data
  safety drafted from the actual data map (emails, audio recordings, ink).
- `review_prompter` (after the "saved a note" happy moment) and `app_updater`
  (forced upgrade via Remote Config).

**Exit:** staging dashboards show crash-free rate and funnels; privacy
checklist signed off.

## M8 — Performance, resilience, device QA

- Real page thumbnails in the reader rail (the standing TODO in
  `score_viewer_screen.dart`) via a cheap thumbnail render path + cache;
  large-PDF memory strategy (page eviction, render scale by zoom); audio note
  size caps/compression.
- Failure-mode audit: quota exceeded, interrupted Storage uploads,
  rules-denied writes — all surfacing as honest UI through the existing
  `Result` plumbing.
- Device-matrix QA (iPad landscape is the design target; phone breakpoints
  exist — verify all <600dp flows); accessibility pass (semantics coverage is
  strong; verify contrast + dynamic type); localization scope decision
  (English now; Hebrew/RTL audit if in scope for 1.0).

**Exit:** performance budgets measured on a low-end device; failure-mode
checklist complete.

## M9 — Release engineering & launch

- CI/CD: GitHub Actions running the melos gate + rules tests + emulator E2E
  on PRs; tagged builds → TestFlight / Play internal per flavor; store
  screenshot automation can reuse `apps/duet/lib/main_screenshot.dart`.
- Store readiness: listings, App Review notes (Apple will test account
  deletion and Sign in with Apple), a seeded demo account on prod.
- Launch runbook: staged rollout (10% → 100%), Crashlytics gates, rules
  rollback procedure, Functions monitoring/alerts, cost alarms.

**Exit:** 1.0 approved and in staged rollout.

---

## Sequencing

```
M0 ─ M1 ─ M2 ─ M3 ─┬─ M4 ─┐
                   └─ M5 ─┼─ M8 (hardening pass) ─ M9
        M6 ────────────────┤   (M6/M7 start any time after M1,
        M7 ────────────────┘    in parallel with M3–M5)
```

Rough shape: M0–M2 ≈ 2 weeks · M3–M5 ≈ 3–4 weeks (the heart of the work) ·
M6–M9 ≈ 3 weeks. Each milestone lands as its own green PR against the full
workspace gate.

## Open decisions (forks in the plan)

| Decision | Affects | Default recommendation |
| --- | --- | --- |
| RevenueCat vs. native StoreKit2/Play Billing | M6 | RevenueCat |
| Invite-link custom domain | M5 | e.g. `link.<app-domain>` |
| Platform priority (iOS-first vs. simultaneous) | M9 | iOS-first, Android fast-follow |
| Hebrew localization in 1.0 | M8 | English-only 1.0, he in 1.1 |

## Post-launch backlog (explicitly out of 1.0)

Presence/live cursors in the reader · system/bar detection (OMR-lite) for
honest passage labels · versioned annotation history · teacher/student roles
(`user_roles` package exists) · practice tools (metronome, tuner) · web
reader.
