# Tandem

**The grocery list you shop together, in real time.** A shared, real-time
grocery list with three-state per-item status, inline who-did-what attribution,
live shopper presence, conversational flags + reactions, and reversible deletes.

Built from the `my_app_empire` factory by composing shared packages. See the
[product brief](../../docs/tandem_product_brief.md) for the why; this README is
the how.

## Run it

```bash
melos bootstrap                 # from the repo root, once
cd apps/tandem
flutter run                     # onboarding → login (any email/pw) → live list
```

On the list screen, watch the simulated collaborator **Dana** enter shopping
mode and grab/flag items live within a few seconds — the real-time experience
with no backend wired.

## What's composed

| Package | Role |
| --- | --- |
| `feature_onboarding` | First-run carousel (Tandem copy) |
| `feature_auth` | Login gate (mock repository) |
| **`feature_grocery_list`** | The product: the live shared list slice |
| `core_ui` | `AppTheme` + `PrimaryButton` |
| `core_utils` | `Result<T>` at repository boundaries |
| `local_storage` | Onboarding-completed flag |

Funnel: **onboarding (first launch) → auth → `GroceryListPage`**, wired in
`lib/app.dart`.

## Architecture

The product lives in `packages/features/feature_grocery_list`, mirroring the
`feature_auth` slice anatomy (`domain/` contracts → `data/` impl → `bloc/` →
`ui/`).

### Domain (`domain/`)

- **Entities** (`grocery_models.dart`): `Collaborator`, `GroceryItem`
  (`status`, `statusBy`/`statusAt` attribution, `flag`/`flagBy`, `reactions`,
  `isDeleted` tombstone), `GroceryList` (active/done/deleted/attention helpers),
  `Shopper`, and the `ItemStatus` / `ItemFlag` / `ItemCategory` enums. All
  immutable `Equatable` value types with `copyWith`.
- **Contracts**: `GroceryRepository` (a `Stream<GroceryList>` for real-time reads
  + `Result<T>`-returning mutations), `PresenceRepository` (live shoppers),
  `ItemCatalog` (suggestions + categorization). The blocs depend only on these.

### Real-time data (`data/`)

`InMemoryGroceryRepository` implements **both** `GroceryRepository` and
`PresenceRepository`. It simulates multi-device sync with a single shared
broadcast `StreamController`: registered as a get_it singleton, every mutation
fans out to all `watchList` subscribers — so two subscriptions behave like two
phones on one list. A `watchList` subscriber receives the **full current list**
first, then a new snapshot on every change.

A **simulated collaborator** (Dana) is driven by cancellable `Timer`s that enter
shopping mode, grab an item, raise a flag, and finish — only when `demo: true`
(off in tests, so no timers leak). Presence uses a heartbeat + TTL; stale
shoppers are pruned so the banner never goes stale.

> **Swap-to-backend seam:** a `FirestoreGroceryRepository` (or Supabase) would
> implement the same two contracts — `watchList → snapshots()`, mutations →
> writes returning `Result` — with **zero** changes to blocs, events, states or
> UI. That's the whole point of keeping contracts in `domain/`.

### State (`bloc/`)

- **`ListBloc`** subscribes to `watchList()` in its constructor (like
  `AuthBloc`), turning remote changes into `ListUpdated` events; user actions are
  forwarded to the repository, whose new snapshot drives state. Events cover add,
  status cycle/undo, flag/clear, react, delete/restore, clear-done, and the
  attention filter.
- **`PresenceBloc`** is kept separate so heartbeat churn never rebuilds the list.

### UI (`ui/`)

Feature-local widgets (too domain-specific for `core_ui`): `ItemRow` (status icon
+ name + attribution chip + flag chip + reaction row; tap to advance, long-press
to flag, swipe to delete), `PresenceBanner`, `AttentionSummary`,
`flag_sheet`, `ListScreen`, and `RecentlyDeletedScreen`. `GroceryListPage` wires
the two blocs for the app.

## Dependency injection

Tandem uses the **showcase-style manual get_it** pattern (`lib/injection.dart`),
not `injectable` codegen — so there's no `build_runner` step. One shared
`InMemoryGroceryRepository` instance is registered against both contracts (the
shared instance is what makes simulated real-time sync work):

```dart
// useFirebase: false (default)
final grocery = InMemoryGroceryRepository();
getIt.registerSingleton<GroceryRepository>(grocery);
getIt.registerSingleton<PresenceRepository>(grocery);
```

The real backend is wired behind the same call — see below.

## Firebase backend

The factory ships real implementations of both contracts; the app picks
in-memory vs Firebase at the DI layer (exactly like `feature_auth`'s mock vs
`FirebaseAuthRepository`). **No bloc, event, state, or UI changes** — only the
binding in `injection.dart`.

### Enable it

```bash
cd apps/tandem
flutterfire configure          # generates firebase_options.dart for your project
# In the Firebase console: create a Firestore database AND enable Realtime Database
flutter run --dart-define=USE_FIREBASE=true
```

`main` calls `Firebase.initializeApp()` and `configureDependencies(useFirebase:
true)`, which binds `FirestoreGroceryRepository` + `FirebasePresenceRepository`.

### The list — Cloud Firestore (`FirestoreGroceryRepository`)

Items live at `households/{listId}/items/{itemId}`. Real-time reads are just a
`snapshots()` listener — **the database does the fan-out, so the in-memory
broadcast plumbing disappears entirely.** Read-modify-write mutations (status
cycle, reactions) run in Firestore transactions so concurrent shoppers don't
clobber each other; the rest are field updates. Deletes are tombstones
(`isDeleted`), keeping the reversible-delete guarantee.

### Presence — Realtime Database `onDisconnect()` (`FirebasePresenceRepository`)

> **Why not just rely on the data stream?** Because a stream propagates
> *writes* — and the hard part of presence is detecting a client that
> **disconnects without writing** (app killed, phone dies, subway, crash). That
> client never gets to write "I left", so a naive presence record would say
> "shopping" forever. That stale state is exactly what the in-memory heartbeat +
> TTL was compensating for.

The fix is to lean on the database with a different primitive: RTDB
`onDisconnect()`. On `enter`, we register a **server-side**
`onDisconnect().remove()` on `presence/{listId}/{userId}`; the server detects
the dropped socket and removes the node for us. So `heartbeat()` becomes a
**no-op** — liveness is handled server-side, no client timers. (Cloud Firestore
has no `onDisconnect`, which is why Firebase's own presence guidance uses RTDB
for connection state; a pure-Firestore presence impl would fall back to the
heartbeat + `lastSeen` + TTL approach the in-memory repo demonstrates.)

## Tests

```bash
melos run lint && melos run test         # from the repo root
```

`feature_grocery_list/test/` covers the acceptance criteria: repository
real-time semantics (two-subscriber sync, status cycle + attribution, flags +
reactions, reversible delete/restore, clear-done, presence enter/leave + TTL +
heartbeat), `ListBloc`/`PresenceBloc` behaviour (`bloc_test` + `mocktail`),
`ItemRow` and `ListScreen` widget tests, and an `apps/tandem` end-to-end widget
test that drives **onboarding → login → live list**.

The Firebase layer is tested too: `FirestoreGroceryRepository` runs against
`fake_cloud_firestore` (add/idempotency, transactional status cycle, flags +
reactions, delete/restore, clear-done, live `snapshots()` updates), the mappers
round-trip, and `FirebasePresenceRepository.parseShoppers` is unit-tested. The
RTDB `onDisconnect()` behaviour itself needs the Firebase Emulator Suite to
exercise end-to-end (no client-side fake simulates a dropped socket).
