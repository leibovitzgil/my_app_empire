---
name: duet-emulator
description: Run the Duet app against the local Firebase Emulator Suite (Auth + Firestore) with one command. Use when asked to run/start Duet with Firebase, develop against the emulators, sign in to Duet, or work on its backend-backed features (auth, collaborator invite-by-email).
---

# Run Duet on local Firebase emulators

Most factory apps run on in-memory mocks (see `run-app`). **Duet** is the one
whose identity + collaborator-directory seams run on **real Firebase** (Auth +
Cloud Firestore). `apps/duet/dev.sh` starts everything against the local
**Emulator Suite** — no real project, no login, nothing touches production.

## Run it

```bash
cd apps/duet
./dev.sh
```

That one command resolves the Firebase CLI (falling back to `npx
firebase-tools`), generates the web platform on first run, builds the Cloud
Functions workspace (`functions/`, npm — skipped when already fresh), starts
the Auth (`:9099`) + Firestore (`:8080`) + Functions (`:5001`) + Storage
(`:9199`) emulators in the `demo-duet` project, seeds two demo accounts, waits
until all are healthy (the Functions probe calls the `healthcheck` callable),
then runs the app wired to them. Quitting the app (`q`) also stops the
emulators.

**Sign in with** `you@duet.dev` / `password` (and `friend@duet.dev` /
`password`, so the invite-by-email flow resolves a real account).

### Options

```bash
./dev.sh -d macos            # device (chrome default; macos/linux/windows/id)
./dev.sh --no-seed           # skip the seeded demo accounts
./dev.sh --emulators-only    # backend only (e.g. to drive the e2e test)
./dev.sh -- <flutter args>   # everything after `--` goes to `flutter run`
```

## Why the extra setup (vs. `run-app`)

- **No in-app sign-up.** `feature_auth` login is sign-in only, so a fresh
  emulator has no account to log in with — `dev.sh` seeds them (an Auth account
  plus a discoverable `usersByEmail` directory doc each).
- **Apps ship without platform folders.** `dev.sh` runs `flutter create
  --platforms=web` on first run (the generated dirs are git-ignored).
- **Two entrypoints:** `lib/main.dart` (in-memory mocks, no Firebase — what the
  headless test gate uses) vs `lib/main_emulator.dart` (real Auth + Firestore).
  The switch is `configureDependencies(useFirebase:)` in `lib/injection.dart`.

## Emulator-backed e2e

Three integration tests drive the real emulators (each seeds its own accounts).
They need the backend up and a device/engine:

```bash
./dev.sh --emulators-only                                            # terminal 1
flutter test integration_test/collaborator_flow_test.dart -d chrome  # terminal 2
flutter test integration_test/cloud_pieces_flow_test.dart -d chrome  #
flutter test integration_test/auth_lifecycle_test.dart   -d chrome   # (or all via melos run e2e)
```

- `collaborator_flow_test.dart` — the email invite → accept funnel.
- `cloud_pieces_flow_test.dart` — the **plan-M3 exit** loop: owner imports +
  uploads a sheet → invites → collaborator accepts (server-side participant
  add) → sees it → draws a stroke offline + records an audio note → reconnect →
  owner sees both live → owner deletes → the collaborator's gallery empties and
  the piece's Storage prefix is gone (the `onPieceDeleted` cascade). Exercises
  all four emulators (**Storage** included).
- `auth_lifecycle_test.dart` — the full identity lifecycle (sign-up →
  directory publish → rename → discoverable toggle → password reset +
  email-verification oobCodes → re-auth → **account deletion**). It also
  exercises the **Functions** emulator (the M1.8 deletion callable), which
  `dev.sh` already boots — no extra setup.

All are opt-in and excluded from the standard headless gate (which only
exercises the in-memory fakes via `test/`).

## Requirements / gotchas

- **Java** (the Firestore emulator is a Java process) and **Node/npm** (builds
  `functions/`; also the `npx firebase-tools` fallback when the Firebase CLI
  isn't installed).
- **Android emulator:** `main_emulator.dart` targets `127.0.0.1`, which on
  Android is the device, not the host — prefer web / desktop / iOS simulator
  (all reach `127.0.0.1` directly), or remap the host to `10.0.2.2`.
- Full walkthrough: [`apps/duet/README.md`](../../../apps/duet/README.md).
