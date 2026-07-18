# Duet failure-mode audit (M8.4)

**Goal (plan M8, bullet 2 / task M8.4):** every cloud failure surfaces as
honest UI through the existing `Result` plumbing — no silent data loss, no raw
error dumps, no failure that ends in a spinner or in silence. The surfacing
vocabulary is fixed by **G4**:

- **Blocking** failure (the screen has nothing useful to show) → `ErrorRetryView`.
- **Transient** failure (the screen stays usable, the action just didn't take)
  → `AppSnackbar.error(...)`.
- Either way the bloc **folds the failure into a `status`/`error` field** — the
  UI never touches a raw exception (`ScoreBloc`, `SettingsBloc` are the pattern).

This is an **audit**: each row below is grounded in a real code path that the
code can actually produce. For every row we assert which surface it reaches
today, and where it was silent we **fixed it** and added a regression test.
Rows already honest are marked *green (already surfaced)* — no invented failures.

---

## Matrix

| # | Failure mode | Real code path | Surface (G4) | Status |
|---|---|---|---|---|
| 1 | **Storage quota exceeded on base-PDF upload** | `FirebasePieceBinaryStore.uploadBasePdf` `putFile` → terminal Storage error thrown out of `await task` as a **stream error** → `ImportPieceBloc._onSubmitted`'s `onError` | `AppSnackbar.error` via `ImportPieceState.submitError`; naming form kept, created piece retained so **retry re-uploads** (no duplicate) | **green (already surfaced)** |
| 2 | **Upload interrupted mid-import** (app killed / cancelled before `basePdfUploaded`) | In-session: `ImportPieceBloc` keeps `_createdPiece`; `ImportCancelled` aborts the managed subscription. Cross-session: piece doc exists with `basePdfUploaded:false`, PDF absent → later reader open `PdfBinaryCache.pathFor` fails to download | In-session: form kept + `submitError` snackbar, retry re-uploads (M3.3 repair). Cross-session: `ScoreStatus.failure` → `ErrorRetryView` on open | **green (already surfaced)** |
| 3 | **Rules-denied WRITE — stale client after collaborator removal** (`OwnershipViolation`) | `ScoreBloc._onStrokeCompleted`/`_onStrokeErased`/`_onUndoRequested`/`_onAudioNoteSaved`/`_onAudioNoteDeleteRequested`: repo maps `permission-denied` → `OwnershipViolation` → `ResultFailure` → folded into `ScoreState.error` (optimistic stroke rolled back) | `AppSnackbar.error` via `ScoreState.error` | **FIXED** — bloc folded the error but the reader's `BlocConsumer` only listened for region changes, so it was **never surfaced**. Now surfaced. |
| 4 | **Rules-denied READ — removed mid-session** (live `watch` errors) | `AnnotationRepository.watch` stream **errors** (`permission-denied`) while the reader is open; `ScoreBloc`'s subscription had **no `onError`** → uncaught zone error, layers silently freeze | `AppSnackbar.error` via `ScoreState.error`, piece stays open on last-seen layers | **FIXED** — added `onError` → `ScoreAnnotationsFailed` → folds into `ScoreState.error`. |
| 5 | **Offline invite send** | `InviteBloc._onSendRequested` → `CollaboratorInviteService.sendInvite` throws inside `Result.guard` (message-gateway offline) → `ResultFailure` → `InviteState.error`, status back to `resolved` | `AppSnackbar.error` via `invite_sheet.dart`; Send button stays, re-tap = retry | **green (already surfaced)** |
| 6 | **Callable deadline** (`deadline-exceeded`) | `CallableInviteService._guarded` maps a `FirebaseFunctionsException` with no typed `reason` → `InviteException(reason: generic)` with the transport message | Send path: `AppSnackbar.error`. Accept path: retryable `ready` + snackbar (generic **stays retryable** — a deadline is transient) | **green (already surfaced)** |
| 7 | **Expired / consumed / invalid token on ACCEPT** (M5.2) | `AcceptInviteCubit.accept` → `acceptInvite` `ResultFailure(InviteException, reason: expired\|consumed\|invalid)` | Terminal `AcceptInviteStatus.failure` → `ErrorRetryView` ("Couldn't open this invite") | **FIXED** — these terminal reasons previously fell through to a retryable `ready` + snackbar (an Accept button that could only fail again). Now a blocking dead-end; `generic` still stays retryable. `load()` already handled the resolve-time expiry. |
| 8 | **Audio-queue poison entry** (upload permanently failing) | `AudioUploadQueue.drain`: a task reaching `maxAttempts` was **silently dropped** (`// Give up.`); `pendingCount` fell to 0 so the sync badge flipped to **"synced"** — silent data loss for a recorded note | Retained in a persisted `failed` (dead-letter) set, exposed via the `failed` count stream + `failedTasks`; user can `skip` (discard) or `retryFailed` | **FIXED** — no longer dropped; surfaced + skippable. |

*Not a row on its own:* an over-cap audio recording (`AudioNoteTooLargeException`,
M8.3) is rejected **before** it can ever enter the queue
(`ensureAudioNoteWithinCap` in `put`) and is surfaced by the reader's
"Recording too large" snackbar — it can never become a poison entry.

---

## The gaps, and the fixes

### Gap A — reader never surfaced `ScoreState.error` (rows 3 + 4)

`ScoreBloc` correctly folds every denied write into `ScoreState.error` (G4's
own reference pattern), **but** `ScoreViewerScreen`'s `BlocConsumer` only
`listenWhen`ed on region-selection changes — so a denied stroke/erase/undo/
audio-note write set `error` and rolled back the optimistic stroke with **no
snackbar at all**. Additionally the live-annotations subscription had no
`onError`, so a mid-session rules-denied **read** (the removed-collaborator
case) escaped as an uncaught zone error and just froze the layers.

**Fix:**

- `apps/duet/lib/features/score/src/bloc/score_bloc.dart` — the
  `AnnotationRepository.watch` subscription gained an `onError` that dispatches
  a new internal `ScoreAnnotationsFailed` event
  (`apps/duet/lib/features/score/src/bloc/score_event.dart`); its handler folds
  the error into `ScoreState.error` (piece stays open — transient, non-blocking).
- `apps/duet/lib/features/score/src/ui/score_viewer_screen.dart` — the
  `BlocConsumer` now also listens for `error` changes and renders
  `AppSnackbar.error(...)` for any non-`failure` status (blocking load failures
  keep rendering `ErrorRetryView` in the body).

**Regression tests** —
`apps/duet/test/features/score/score_bloc_test.dart`, group
`failure surfacing (M8.4)`:
- *"a rules-denied stroke write folds into state.error and rolls back the
  optimistic undo entry (stale client after removal)"*
- *"a live-annotations read failure (mid-session permission-denied) folds into
  state.error instead of a swallowed stream error"*

### Gap B — expired/consumed/invalid token on accept was retryable (row 7)

`AcceptInviteCubit.accept` mapped only `atCap`/`alreadyCollaborator` to their
dedicated screen states and let **everything else** fall through to a retryable
`ready` + snackbar. For a token that is invalid, expired, or already consumed,
that leaves an **Accept button that can only ever fail again**. The resolve-time
path (`load`) already renders the terminal `failure` dead-end for these; accept
now matches it.

**Fix:** `apps/duet/lib/features/pairing/src/bloc/accept_invite_cubit.dart` —
`invalid | expired | consumed` map to `AcceptInviteStatus.failure` (→
`ErrorRetryView`), carrying the error message. `generic` (transport/deadline)
still stays on retryable `ready`.

**Regression test** —
`apps/duet/test/features/pairing/accept_invite_cubit_test.dart`:
*"a typed `<reason>` denial from accept is terminal (failure), not a retryable
ready state"* (parameterised over expired / consumed / invalid).

### Gap C — audio-queue poison entry was silent data loss (row 8)

`AudioUploadQueue.drain` **silently dropped** a task once it hit `maxAttempts`
(default 5). Because the drop decrements `pendingCount`, the sync badge
(`FirestorePieceSyncMonitor` folds queue depth into `PieceSyncState`) flipped
back to **"synced"** even though a recorded note never reached Storage — the
worst kind of silent loss.

**Fix:** `apps/duet/lib/data/audio_upload_queue.dart` — a task that exhausts its
attempts is moved to a persisted **`failed` (dead-letter) set** instead of being
dropped. New surface seam:
- `Stream<int> get failed` + `int get failedCount` + `List<AudioUploadTask>
  get failedTasks` — the app can show which notes gave up (it is **surfaced**,
  not lost);
- `Future<void> skip(String assetId)` — the user permanently discards a poison
  entry (it is **skippable**);
- `Future<void> retryFailed()` — re-queues failed entries with a fresh attempt
  count once connectivity returns.

The active `pending` queue (and thus the existing badge) is unchanged; poison
entries simply no longer masquerade as "synced".

**Regression tests** — `apps/duet/test/data/audio_upload_queue_test.dart`:
- *"a task poisons to the failed set (not silently dropped) after maxAttempts
  failed drains"*
- *"the failed stream emits the poison count when a task gives up"*
- *"skip permanently discards a failed (poison) entry"*
- *"retryFailed re-queues poison entries with a fresh attempt count"*
- *"poison entries survive a restart (fresh instance, same store)"*

---

## Verification

Trimmed gate (per task) on the touched package `apps/duet`:

- `flutter analyze apps/duet` — **No issues found.**
- `flutter test apps/duet --exclude-tags golden` — **646 passing** (the
  standard `melos run test` gate excludes `golden`). Golden baselines are
  platform/font-sensitive and were not regenerated here; no golden-rendered
  widget state is touched by these fixes.

**Done:** every failure mode above lands on `ErrorRetryView`, `AppSnackbar.error`,
or a bloc failure field — none ends in a spinner or in silence.
