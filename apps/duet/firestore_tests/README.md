# Duet Firestore rules tests

Executable coverage of [`../firestore.rules`](../firestore.rules) using
[`@firebase/rules-unit-testing`](https://firebase.google.com/docs/rules/unit-tests)
+ vitest. An npm workspace, deliberately **outside melos** (like
`../functions/`): `melos run test` stays headless-Dart-only, and this suite
runs wherever a Firestore emulator can.

## Run it

```bash
cd apps/duet/firestore_tests
npm ci        # first time
npm test      # boots a Firestore emulator around vitest (emulators:exec)
```

`npm test` uses the pinned `firebase-tools` from devDependencies and the
emulator config from [`../firebase.json`](../firebase.json) (the CLI finds it
by walking up). With a suite already running (e.g. `../dev.sh
--emulators-only`), skip the boot:

```bash
npm run test:against-running
```

From the repo root there's also `melos run rules-test`. CI runs the same
suite via the node-only `rules-tests` job in `.github/workflows/ci.yaml`.

## What's covered

The current rules matrix, one `describe` per collection: `usersByEmail`
(exact-key get gated on `discoverable`, list always denied, owner-only
writes — including the invite-hijack regression), `deviceTokens` (self
only), `userInbox` (recipient read/update, path-matching create — the
documented v1 spam-vector behavior M2.4 replaces — delete never), and the
deny-by-default catch-all.

## Extending it (M2.3)

When the pieces schema lands, add fixtures for owner/collaborator/stranger
and one `describe` per new collection (`pieces`, `layers`, `notes`,
`reads`), either in `test/firestore_rules.test.ts` or as sibling files —
everything matching `test/**/*.test.ts` runs. Storage-rules coverage joins
via `initializeTestEnvironment`'s `storage` option once `storage.rules`
grows real content.
