# Duet cloud schema

The single source of truth for Duet's Firestore + Cloud Storage data model.
Every M3–M5 task implements **against this document**; `firestore.rules`
(M2.2) translates the [ACL matrix](#acl-matrix) 1:1; `firestore.indexes.json`
(M2.2) provides the [indexes](#indexes). Design-before-code: this doc has no
code of its own — it records the shape, the types, the local↔cloud mapping,
and who may touch each document, so later tasks don't re-decide any of it.

> **Status.** Piece/annotation storage is **on-device today**
> (`LocalPieceRepository` / `LocalAnnotationRepository`, via `local_storage`)
> — no `pieces` collection exists in Firestore yet. This doc defines the
> Firestore-backed model that M3 (piece sync) and M4 (annotation sync) build.
> The identity/discovery collections it references as **live** — `usersByEmail`,
> `deviceTokens`, `userInbox` — already exist and are governed by
> `apps/duet/firestore.rules` (M1). This doc **supersedes** the commented-out
> `pieces` sketch in that rules file (see [Naming](#naming-supersession)).

## Conventions

- **Timestamps are Firestore `Timestamp`.** The local JSON model
  (`piece_mappers.dart`, `annotation_mappers.dart`) stores `DateTime` as
  **ISO-8601 strings**; the Firestore mappers (M3+) convert to/from
  `Timestamp` at the boundary. Every `*At` field below is a `Timestamp`.
- **Fractional coordinates.** Ink points and note regions are fractions of the
  rendered page (0.0–1.0), so annotations stay aligned across devices/zoom —
  unchanged from the local model (`InkPoint`, `Region`).
- **IDs are client-generated** (the local repositories already mint stable
  ids); the cloud keeps them as document ids so a piece/note/stroke keeps its
  identity across the local→cloud migration.
- **Owner vs. participant.** The *owner* imported the piece. *Participants* =
  owner + collaborators. `participantIds` is the `array-contains` query key for
  "every piece I can see".

---

## Firestore collections

### `/pieces/{pieceId}`

The piece metadata document. Mirrors the `Piece` entity
(`packages/core/pieces/lib/src/domain/piece.dart`) and its local JSON shape
(`piece_mappers.dart`), with three deliberate cloud-only changes noted inline.

```jsonc
{
  "title": "Clair de Lune",
  "ownerId": "uid_abc",
  "ownerName": "Sam",                 // nullable — absent when unknown at import
  "participantIds": ["uid_abc", "uid_def"],   // MATERIALIZED (see note)
  "collaborators": [                  // embedded array, matches piece_mappers
    { "uid": "uid_def", "name": "Ravi", "email": "ravi@example.com" }
  ],
  "basePdfChecksum": "9f86d081…",     // sha256 hex of the base PDF bytes
  "createdAt": <Timestamp>,
  "updatedAt": <Timestamp>
}
```

| Field | Type | Notes |
| --- | --- | --- |
| `title` | `string` | Display title. |
| `ownerId` | `string` | The importing user's uid. Immutable after create. |
| `ownerName` | `string?` | Owner's display name if known at import; UI falls back to an initials-from-id placeholder. |
| `participantIds` | `string[]` | **Materialized** = `[ownerId, ...collaborator uids]`. Today this is a *derived getter* (`Piece.participantIds`); in Firestore it's a stored field so a client can run `where('participantIds', arrayContains: myUid)`. Kept in sync **only** by the collaborator-mutation Function (never client-written directly). |
| `collaborators` | `array<{uid, name?, email?}>` | Embedded, insertion-ordered (earliest-invited first). Exactly the `Collaborator` shape from `piece_mappers.dart`. |
| `basePdfChecksum` | `string` | sha256 hex of the original PDF bytes (`PdfRenderService.checksum` → `sha256.convert(bytes)`). Keys the local render cache and the Storage-object dedupe (see [Storage](#cloud-storage-layout)). |
| `createdAt` | `Timestamp` | First import. |
| `updatedAt` | `Timestamp` | Last metadata change. Drives library recency ordering and the unread heuristic. |

- **Not stored in Firestore:** `Piece.basePdfPath` is an on-device path — the
  cloud equivalent is the Storage object `pieces/{id}/base.pdf`, resolved by
  convention from the piece id, not persisted as a field.
- **`collaborators` + `participantIds` are Function-maintained.** A client
  never edits them directly: adding/removing a collaborator must atomically
  update both, enforce the per-piece cap (`CollaboratorLimits`, which depends
  on monetization state rules can't read), and is therefore a Cloud Function
  (G7) — see [Function-only mutations](#function-only-mutations). Owners may
  still update `title`/`updatedAt` client-side.

### `/pieces/{pieceId}/layers/{uid}`

One document **per author**, id = the author's uid. This is the cloud
projection of the local `InkLayer` (`ink_layer.dart`), and the key
architectural decision of annotation sync: **each participant writes only their
own layer doc**, so concurrent annotation is conflict-free by construction
(plan architecture decision 1) — no two writers ever touch the same document.
Locally, all layers live in one bundled `PieceAnnotations` blob; the cloud
splits them per-author.

```jsonc
{
  "ownerId": "uid_def",               // == the doc id == authorId of every stroke
  "role": "collaborator",             // "owner" | "collaborator" (PieceRole.name)
  "strokes": [
    {
      "id": "stroke_1",
      "authorId": "uid_def",
      "pageIndex": 0,
      "colorId": "amber",
      "points": [ { "x": 0.12, "y": 0.34 }, { "x": 0.13, "y": 0.35 } ]
    }
  ],
  "updatedAt": <Timestamp>,           // cloud-only (not in local InkLayer)
  "rev": 7                            // cloud-only, monotonically increasing
}
```

| Field | Type | Notes |
| --- | --- | --- |
| `ownerId` | `string` | The author. Equals the document id and the `authorId` of every stroke in `strokes`. |
| `role` | `string` | `PieceRole.name`: `owner` \| `collaborator`. Reader projects this into `ParticipantLayer` (`feature_score`). |
| `strokes` | `array<InkStroke>` | `{id, authorId, pageIndex, colorId, points:[{x,y}]}` — exactly `inkStrokeToJson`. |
| `updatedAt` | `Timestamp` | **New (cloud-only).** Last write to this layer; drives the reader's "new annotations" attention markers (M4.3) and unread dots (M3.7). |
| `rev` | `int` | **New (cloud-only).** Monotonically increasing per write, so a reader can cheaply detect "has this layer advanced since I last saw it" without diffing strokes. |

### `/pieces/{pieceId}/notes/{noteId}`

One document per audio note, id = the note id. Mirrors `AudioNote`
(`audio_note.dart` / `audioNoteToJson`), plus a tombstone field.

```jsonc
{
  "id": "note_1",
  "authorId": "uid_def",
  "audioAssetId": "asset_9",          // resolves to Storage pieces/{id}/audio/{assetId}
  "pageIndex": 0,
  "durationMs": 4200,
  "region": { "pageIndex": 0, "left": 0.1, "top": 0.2, "width": 0.3, "height": 0.05 },
  "createdAt": <Timestamp>,
  "deletedAt": null                   // Timestamp? tombstone — cloud-only
}
```

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `string` | Stable note id (also the doc id). |
| `authorId` | `string` | Recording participant's uid. |
| `audioAssetId` | `string` | Id of the audio object in Storage (`pieces/{id}/audio/{assetId}`). |
| `pageIndex` | `int` | Zero-based page the note was recorded on. |
| `durationMs` | `int` | Recording length. |
| `region` | `{pageIndex, left, top, width, height}` | Fractional pin location (`Region`). |
| `createdAt` | `Timestamp` | When recorded. |
| `deletedAt` | `Timestamp?` | **New (cloud-only) tombstone.** Soft-delete marker so a delete converges across offline peers instead of resurrecting (M4.4 uses it). `null`/absent = live. Notes are never hard-deleted by clients. |

### `/pieces/{pieceId}/reads/{uid}`

One document per participant, id = the reader's uid — the **persistent unread
watermark**.

```jsonc
{ "lastOpenedAt": <Timestamp> }
```

| Field | Type | Notes |
| --- | --- | --- |
| `lastOpenedAt` | `Timestamp` | When this user last opened this piece. |

This backs the "unread dots" the library already wants. Today
`LibraryState.isUnread` derives unread from
`updatedAt.isAfter(createdAt) && !viewedPieceIds.contains(id)`, where
`viewedPieceIds` is **session-local** — its own doc comment explicitly calls
for "a persistent `lastViewedAt` store". This collection **is** that store:
unread becomes `piece.updatedAt > reads/{me}.lastOpenedAt` (M3.7), and it also
feeds the reader's attention markers (M4.3).

### `/inviteTokens/{token}`

One document per outstanding tokenized deep-link invite, id = the opaque
token. Mirrors `_StoredInvite`
(`feature_pairing/lib/src/data/deep_link_invite_service.dart`), promoting two
fields to server-managed (M5.2).

```jsonc
{
  "pieceId": "piece_1",
  "ownerId": "uid_abc",
  "ownerName": "Sam",                 // nullable
  "createdAt": <Timestamp>,           // local model: createdAtMillis (int)
  "expiresAt": <Timestamp>,           // new — server-set TTL
  "consumed": false,
  "consumedBy": null                  // new — uid that redeemed it (server-set)
}
```

| Field | Type | Notes |
| --- | --- | --- |
| `pieceId` | `string` | The piece the token grants access to. |
| `ownerId` | `string` | The inviting owner's uid. |
| `ownerName` | `string?` | Owner display name for the accept screen. |
| `createdAt` | `Timestamp` | Issued-at. Local model stores `createdAtMillis` (int epoch) — the mapper converts. |
| `expiresAt` | `Timestamp` | **New.** Server-set expiry; the accept flow rejects an expired token (M5.4). |
| `consumed` | `bool` | Redeemed flag. |
| `consumedBy` | `string?` | **New.** The uid that redeemed it. Set **only** by the acceptance Function (redemption adds the collaborator + enforces the cap atomically — see [below](#function-only-mutations)). |

> **A token is an invitation, not a view grant.** Holding the link lets a
> signed-in user *read this token document* — `pieceId` + `ownerName`, enough
> to render the accept screen ("Sam invited you to Clair de Lune") — and
> **nothing else**. It grants **no** read on the piece: `pieces/{id}` and every
> subcollection (`layers`, `notes`, `reads`) are gated on participant
> membership (`P`), and a link-holder is **not** a participant until they
> *accept* and the redemption Function adds them to `participantIds` (subject
> to the cap). So a stranger with only the link can never see notes,
> annotations, or even the piece metadata beyond the owner's name — they see
> an invitation, and access begins at redemption. (This is deliberate
> capability-URL design: the token doc is readable by whoever holds the
> unguessable token, but it is inert — it carries no content.)

### `/entitlements/{uid}`

One document per user, id = uid — the server-authoritative monetization state
(M6.3). Clients **read** it and **never write** it (a client-writable
entitlement is trivially cheatable).

```jsonc
{
  "pro": true,
  "updatedAt": <Timestamp>,
  "source": "revenuecat"              // provenance: "revenuecat" | "promo" | "manual"
}
```

| Field | Type | Notes |
| --- | --- | --- |
| `pro` | `bool` | Whether the `pro` entitlement is active (matches `MonetizationService.isProUser`, entitlement id `pro`). |
| `updatedAt` | `Timestamp` | Last change. |
| `source` | `string` | Where the grant came from (RevenueCat webhook, promo, manual). |

### Live identity collections (M1 — governed by `firestore.rules` today)

Defined by the current rules file; listed here so this doc is the complete map.
`usersByEmail/{emailKey}` (discoverable directory), `deviceTokens/{uid}`
(push-token registry), `userInbox/{uid}/messages/{messageId}` (generic message
inbox invites ride over). Their ACLs are already in
`apps/duet/firestore.rules`; the [ACL matrix](#acl-matrix) restates them for
completeness and marks the one M2.4 change (inbox `create` moves behind a
Function).

---

## Cloud Storage layout

Per-piece objects, keyed by piece id:

| Object | Notes |
| --- | --- |
| `pieces/{pieceId}/base.pdf` | The original PDF. **Custom metadata `checksum`** = the same sha256 hex as `pieces/{pieceId}.basePdfChecksum`. |
| `pieces/{pieceId}/audio/{assetId}` | One object per audio note asset. `assetId` = the id minted by `AudioAssetStore.put` and stored on `notes/{noteId}.audioAssetId`. |

**Dedupe decision (recorded once, here).** Objects are **per-piece**, not
global. The `basePdfChecksum` keys the **local** render cache and suppresses
**re-upload of an identical PDF for the _same_ piece** (re-importing the same
file doesn't re-push bytes). There is deliberately **no cross-piece global
content-addressed object store**: two pieces that happen to share a PDF keep
independent objects. Rationale: cross-piece sharing would couple unrelated
pieces' lifecycles (delete/ACL) to a shared blob, for savings that don't
matter at this scale.

---

## Region, offline, indexes

### Region

All Firestore/Storage/Functions resources live in **one region**, decided when
the real projects are created (M0.H) and recorded in
`docs/duet_environments.md`. The Functions region is pinned in
`functions/src/region.ts` (`europe-west1` placeholder, `TODO(M0.H)`) and must
match `apps/duet/dev.sh`'s `REGION` and `duetFunctionsRegion` in
`callable_account_purge.dart`.

### Offline persistence

Firestore offline persistence is **on** for mobile (the SDK default) — this is
what makes annotate-offline-then-reconnect converge (M4). **Web persistence is
not required for 1.0** (the reader is the mobile surface); revisit if a web
build ships.

### Indexes

`firestore.indexes.json` (M2.2) must provide:

| Query | Index |
| --- | --- |
| "Every piece I participate in, newest first" (the library) | Composite: `participantIds` **array-contains** + `updatedAt` **desc**. |

Subcollection reads (`layers`, `notes`, `reads`) are collection-scoped and
single-field — no composite index needed for v1. Add one only if a real query
demands it (name it in the task that introduces the query).

---

## ACL matrix

M2.2 translates this table directly into `firestore.rules`. `P` = "is a
participant on the parent piece" (`request.auth.uid in
get(pieces/{id}).data.participantIds`); `self` = the doc id equals
`request.auth.uid`. Everything not listed is deny-by-default.

| Document | create | read | update | delete |
| --- | --- | --- | --- | --- |
| `pieces/{id}` | owner (`auth.uid == ownerId`, and `participantIds == [ownerId]`, `collaborators == []`) | `P` | **owner**, and only non-membership fields (`title`, `updatedAt`, `basePdfChecksum`); `collaborators`/`participantIds`/`ownerId` immutable to clients → **Function** | owner |
| `pieces/{id}/layers/{uid}` | `self` **and** `P` (author writes own layer) | `P` | `self` **and** `P` | `self` (piece deletion cascades via Function) |
| `pieces/{id}/notes/{noteId}` | `P`, `authorId == auth.uid` | `P` | author only (e.g. set `deletedAt`) | **never** (tombstone via `deletedAt`) |
| `pieces/{id}/reads/{uid}` | `self` **and** `P` | `self` | `self` **and** `P` | `self` |
| `inviteTokens/{token}` | owner of `pieceId` (`auth.uid == ownerId`) | `auth != null` — **the token doc only** (invite preview: `pieceId` + `ownerName`); grants **no** read on the piece, whose content stays `P`-gated | **Function only** (redemption sets `consumed`/`consumedBy`) | owner |
| `entitlements/{uid}` | **Function only** | `self` | **Function only** | **Function only** |
| `usersByEmail/{email}` *(M1, live)* | self (`auth.uid == resource.uid`) | `get` if `discoverable` or self; **no `list`** | self (owner of existing doc + new doc) | self |
| `deviceTokens/{uid}` *(M1, live)* | `self` | `self` | `self` | `self` |
| `userInbox/{uid}/messages/{id}` *(M1, live)* | v1: any signed-in sender w/ matching `toUid`; **M2.4 → Function only** | recipient (`self`) | recipient | **never** |

### Function-only mutations

Client mutations the rules can't safely express, named here so each has a home
(G7 — "if a rule can't check it, it's a Function"):

1. **Collaborator add (invite acceptance).** Atomically appends to
   `pieces/{id}.collaborators` + `participantIds`, enforces the per-piece cap
   (`CollaboratorLimits`, which reads monetization state), and sets
   `inviteTokens/{token}.consumed`/`consumedBy`. (M2.4 pulls acceptance
   server-side; M5 wires the tokenized + email paths to it.)
2. **Collaborator remove / leave.** The reverse — removes from both arrays.
3. **Inbox send** (`userInbox/.../messages` create). v1 lets any signed-in
   client write (documented spam vector); **M2.4** moves it behind a Function
   that authorizes the sender.
4. **Invite token redemption** (`inviteTokens/{token}` update). Only the
   acceptance Function sets `consumed`/`consumedBy`.
5. **Entitlement writes** (`entitlements/{uid}`). Only the RevenueCat webhook /
   server (M6.3) — never a client.
6. **Account purge** (already shipped: `deleteAccount` callable, M1.8) — deletes
   everything a uid owns server-side.

---

## Naming supersession

The commented-out `pieces` sketch in `apps/duet/firestore.rules` (~L63–76)
uses `teacherId` / `collaboratorIds`. The real model — and this doc — use
**`ownerId`** and **`participantIds`** (materialized owner + collaborators),
matching the `Piece` entity and `piece_mappers.dart`. When M2.2 writes the real
rules, it deletes that sketch; this document is the reference it works from.
