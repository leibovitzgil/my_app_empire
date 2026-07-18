# Duet — Privacy Data Map (M7.4)

The authoritative enumeration of the personal data Duet collects, why, where it
lives, and how long it is kept. It is the source of truth that the store
privacy disclosures must match.

> **[HUMAN] / Track B:** transcribe this map into Apple's **App Privacy**
> labels (App Store Connect) and Google's **Play Data Safety** form. M9.4
> blocks on those forms being filled. Keep them in lockstep with this file —
> if a future feature collects a new data type, add a row here first, then
> update both console forms.

## Scope & sources

Data types below are derived from the app's Firestore/Storage schema and the
services Duet composes (auth, user directory, push, annotations, audio notes,
PDF import, monetization, analytics). "Retention" describes the intended
lifecycle; account deletion (M1.8/M1.9) purges account-scoped data server-side,
and self-service export (M7.5) returns a copy of it.

## Collected data

| Data type | Example / field | Purpose | Linked to identity | Where stored | Retention |
| --- | --- | --- | --- | --- | --- |
| **Email address** | `users/{uid}.email`, auth record | Account identity, sign-in, collaborator invite-by-email resolution | Yes | Firebase Auth + `usersByEmail` (directory) | Life of account; deleted on account deletion |
| **Display name** | `users/{uid}.displayName` | Show who authored notes / who is collaborating | Yes | Firebase Auth + Firestore user directory | Life of account; deleted on account deletion |
| **Device push tokens** | `deviceTokens/{uid}` | Deliver collaboration push notifications (invites, nudges, digests) | Yes | Firestore | Until token rotates or account deletion; stale tokens pruned |
| **Ink strokes / annotations** | `pieces/{id}/layers/*`, notes | Core product: the user's markings on sheet music, synced across their devices and to collaborators on shared pieces | Yes | Firestore | Life of the piece; deleted with the piece or account |
| **Audio recordings (notes)** | `pieces/{id}/audio/{assetId}` | Core product: voice notes attached to a score | Yes | Cloud Storage (local-only in mock builds) | Life of the piece; deleted with the piece or account |
| **PDFs (imported sheet music)** | `pieces/{id}/base.pdf` + metadata | Core product: the score the user reads and annotates | Yes | Cloud Storage + Firestore metadata | Life of the piece; deleted with the piece or account |
| **Purchase / entitlement state** | Pro entitlement, subscription status | Unlock Pro (raises per-sheet collaborator cap); restore purchases | Yes (via store account) | Store (App Store / Play) + monetization provider; cached client-side | Managed by the store/provider; entitlement cache cleared on sign-out/deletion |
| **Analytics events** | Funnel events (sign-up, import, note recorded, paywall) | Understand product usage and conversion; diagnose drop-off | Pseudonymous (app-instance / uid where set) | Analytics backend (Track B; local-only today) | Per analytics provider's retention policy |
| **Crash diagnostics** | Stack traces, breadcrumbs, uid | Diagnose and fix crashes | uid only (never email) | Crash-reporting backend (Track B; no-op today) | Per provider's retention policy |
| **Legal consent record** | `consent/{uid}` — `documentVersion`, `acceptedAt` | Record that the user accepted the ToS + Privacy Policy at sign-up (M7.4) | Yes | Firestore (`consent/{uid}`; in-memory in mock builds) | Life of account; deleted on account deletion |

## Notes for the store forms

- **Data used to track you:** none today — Duet ships **no** ads/tracking SDKs,
  which is exactly why the consent mechanism is a minimal in-house acceptance
  record and **not** a CMP. If an ad/tracking SDK ever lands, revisit both the
  consent flow (a real CMP) and the "tracking" section of the store forms.
- **Data linked to you:** email, display name, device tokens, annotations,
  audio, PDFs, purchase state, consent record (all account-scoped).
- **Data not linked / pseudonymous:** analytics and crash diagnostics are keyed
  by app instance / uid, never by email.
- **Account deletion:** all account-scoped rows are purged server-side on
  deletion (M1.8/M1.9); self-service export (M7.5) returns a copy on request.
- **Third parties:** Firebase (Auth, Firestore, Storage, Messaging), the app
  store billing/monetization provider, and — once wired (Track B) — the
  analytics and crash-reporting backends. List each in the store forms' data
  recipients section.
