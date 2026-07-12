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

Everything matching `test/**/*.test.ts` runs; one `describe` per collection.

- **`firestore_rules.test.ts`** (M1 identity): `usersByEmail` (exact-key get
  gated on `discoverable`, list always denied, owner-only writes — including
  the invite-hijack regression), `deviceTokens` (self only), `userInbox`
  (recipient read/update, path-matching create — the documented v1 spam-vector
  M2.4 replaces — delete never), deny-by-default catch-all.
- **`pieces_rules.test.ts`** (M2.3): the full create/read/update/delete × role
  matrix (owner / collaborator / stranger / anon) for `pieces` and its
  `layers`/`notes`/`reads` subcollections — participant gating, the
  sole-participant create invariant, collaborator-set immutability to clients,
  author-only layer/note writes, the `deletedAt`-only note tombstone, and
  self-only read watermarks.
- **`storage_rules.test.ts`** (M2.3): `pieces/{id}/base.pdf` +
  `audio/{assetId}` — participant read, owner-only base write, participant
  audio write, the 5 MB size cap, deny-by-default. Membership is a
  cross-service `firestore.get`, so these seed the gating piece doc in
  Firestore; both emulators must be up (`npm test` boots `firestore,storage`).

## Extending it

Add fixtures + a `describe` in the matching file, or a new sibling
`test/*.test.ts`. New collections (`inviteTokens` M5.2, `entitlements` M6.3)
get their own file when their rules land.
