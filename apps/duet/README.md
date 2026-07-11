# Duet

**Collaborative sheet music & mentorship.** Import a score, mark it up, record
a take, and invite a collaborator by email to review it with you.

Duet is composed from the `my_app_empire` factory (auth, library, score reader,
pairing, paywall, settings) and — unlike the pure in-memory reference apps — its
identity and collaborator-directory seams run on **real Firebase** (Auth +
Cloud Firestore). This guide is about running it locally against the **Firebase
Emulator Suite**, so you get the real backend behaviour with nothing touching a
live project.

## Run it

From the repo root, once:

```bash
melos bootstrap
```

Then, one command:

```bash
cd apps/duet
./dev.sh
```

That's it. `dev.sh` builds the Cloud Functions, starts the Auth + Firestore +
Functions + Storage emulators, seeds two demo accounts, and launches Duet (in
Chrome by default) wired to them. When it's up, **sign in with:**

| Email | Password |
| --- | --- |
| `you@duet.dev` | `password` |
| `friend@duet.dev` | `password` |

Sign in as `you@duet.dev`, add a score, open its **collaborators / invite**
sheet and invite `friend@duet.dev` — the email resolves against the seeded
Firestore directory, exactly as it would in production.

Press `q` in the terminal to quit; that also stops the emulators.

### Options

```bash
./dev.sh -d macos            # run on another device (chrome, macos, linux, windows, a device id)
./dev.sh --no-seed           # start without the demo accounts
./dev.sh --emulators-only    # just the backend (e.g. to drive the e2e test yourself)
./dev.sh -- --profile        # pass anything after `--` straight to `flutter run`
DUET_DEVICE=chrome ./dev.sh  # device via env var
```

## What it's doing

- **Emulators, not the cloud.** The project id is `demo-duet`. Any Firebase
  project id starting with `demo-` runs the emulators in *demo mode*: no real
  project, no credentials, no login — and it's impossible to accidentally read
  or write production data. Config is in [`firebase.json`](firebase.json);
  [`.firebaserc`](.firebaserc) makes `demo-duet` the default project.
- **The emulator suite:** Auth on `127.0.0.1:9099`, Firestore on
  `127.0.0.1:8080` (with [`firestore.rules`](firestore.rules) enforced — the
  same rules that ship to production), Cloud Functions on `127.0.0.1:5001`,
  and Storage on `127.0.0.1:9199` (with [`storage.rules`](storage.rules) —
  a deny-all placeholder until the pieces schema lands). The app points at
  Auth + Firestore in [`lib/main_emulator.dart`](lib/main_emulator.dart).
- **Cloud Functions** live in [`functions/`](functions/) — a TypeScript npm
  workspace (deliberately outside melos). `dev.sh` installs + compiles it
  before starting the emulators (skipped when already fresh) and waits until
  the `healthcheck` callable answers:

  ```bash
  curl -X POST http://127.0.0.1:5001/demo-duet/europe-west1/healthcheck \
    -H 'Content-Type: application/json' -d '{"data":{}}'
  # → {"result":{"status":"ok","service":"duet-functions"}}
  ```

  Develop it with `npm run build` / `lint` / `test` from `functions/`, or run
  the whole install→lint→build→test chain from the repo root with
  `melos run functions-test` (the CI entry point).
- **Deploy targets beyond dev.sh:** [`firebase.json`](firebase.json) also
  configures Firestore indexes ([`firestore.indexes.json`](firestore.indexes.json),
  empty for now) and Hosting ([`hosting/`](hosting/), a placeholder page the
  invite-link fallback will replace). A plain `firebase emulators:start` (or
  `npx firebase-tools emulators:start`) from `apps/duet/` boots all five
  emulators including Hosting on `127.0.0.1:5000`; `firebase deploy` can
  target `firestore`, `storage`, `functions`, and `hosting` once real
  projects exist.
- **Fresh each run.** The emulators start empty every time and the two demo
  accounts are re-seeded on startup, so sign-in always works. (Scores and
  annotations are stored on-device, not in Firestore, so they're independent
  of the emulator anyway.)
- **Platform scaffolding is generated on demand.** The factory's apps are
  composable packages that don't commit `web/`, `macos/`, etc. — `dev.sh`
  runs `flutter create --platforms=<target>` for you the first time (and the
  generated dirs are git-ignored).

## Emulator vs. mock

Duet has two entrypoints:

| Entrypoint | Backend | Use |
| --- | --- | --- |
| [`lib/main.dart`](lib/main.dart) | In-memory mocks, **no Firebase** | `flutter run` — quickest look at the UI; also what the headless test gate uses |
| [`lib/main_emulator.dart`](lib/main_emulator.dart) | **Real Auth + Firestore** on the local emulators | `./dev.sh` — the real backend behaviour |

The choice is made in one place — [`lib/injection.dart`](lib/injection.dart)'s
`configureDependencies(useFirebase:)` — so the auth / user-directory /
messaging seams swap between an in-memory fake and a Firestore-backed
implementation with no change to blocs, screens, or routing.

## The emulator-backed end-to-end test

[`integration_test/collaborator_flow_test.dart`](integration_test/collaborator_flow_test.dart)
drives the invite → accept funnel against the **real** emulators (it seeds its
own accounts, so it doesn't depend on `dev.sh`'s demo data). It needs the
emulators running and a device/engine:

```bash
./dev.sh --emulators-only            # terminal 1: backend only
flutter test integration_test/collaborator_flow_test.dart -d chrome   # terminal 2
```

It's opt-in and excluded from the standard headless gate (which only exercises
the in-memory fakes via `test/`).

## Requirements

- **Flutter** (the repo's `melos bootstrap` handles Dart package deps).
- **Java** — the Firestore emulator is a Java process. `java -version` should
  work.
- **Node + npm** — builds the Cloud Functions workspace (`functions/`).
- **Firebase CLI** — `dev.sh` uses `firebase` if it's on your PATH, otherwise
  falls back to `npx firebase-tools` (downloaded on first run). For the snappiest
  start: `npm i -g firebase-tools`.

The first run downloads the Firestore emulator jar (once, cached by the CLI).

### Notes

- **Android emulator:** `main_emulator.dart` points at `127.0.0.1`, which on an
  Android emulator is the device itself, not your host — Android would need the
  host mapped to `10.0.2.2`. Web, desktop, and the iOS simulator all reach
  `127.0.0.1` directly, so `./dev.sh` (Chrome) is the friction-free path.
