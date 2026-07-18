import { randomInt } from 'node:crypto';

import { Timestamp } from 'firebase-admin/firestore';
import type { DocumentSnapshot } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import type { FunctionsErrorCode } from 'firebase-functions/v2/https';

import { capFor, ownerIsPro } from './collaboratorLimits';
import { db } from './firebase';
import { REGION } from './region';

/**
 * Tokenized deep-link invites as single-use, expiring Firestore docs
 * (task M5.2), per docs/duet_cloud_schema.md `/inviteTokens/{token}`.
 *
 * The collection is entirely Function-owned: the rules deny every client
 * read/write (an unguessable id is not an ACL), so these three callables are
 * the only surface —
 *
 * - `createInviteToken`: owner-only + cap-checked mint; the doc id IS the
 *   opaque token; `expiresAt = now + 14d`.
 * - `resolveInviteToken`: read-only preview (piece title + owner) for the
 *   Accept Invite screen, kept separate from acceptance so merely opening a
 *   link can never consume it.
 * - `acceptInviteToken`: transactional redemption — exists ∧ !consumed ∧
 *   !expired → append the caller to the piece's `participantIds` /
 *   `collaborators` → mark `consumed`/`consumedBy`, atomically.
 *
 * Expiry is ALWAYS checked here at resolve/accept time: the Firestore TTL
 * policy on `expiresAt` (a [HUMAN] console step, see below) only garbage-
 * collects expired docs and lags up to ~72 h behind the timestamp.
 *
 * [HUMAN] TTL policy (per environment, once): Console → Firestore → TTL →
 * create policy on collection `inviteTokens`, field `expiresAt` — or
 * `gcloud firestore fields ttls update expiresAt
 *  --collection-group=inviteTokens --enable-ttl`. The emulator has no TTL;
 * nothing in these functions depends on it.
 *
 * Every denial carries a machine-readable `details.reason` (see
 * [InviteTokenErrorReason]) so the Dart `CallableInviteService` can map it
 * onto the existing `AcceptInviteStatus` states (expired/consumed render the
 * standing failure copy; `at-cap`/`already-collaborator` map to their
 * dedicated screen states).
 */

/** How long a minted invite token stays redeemable. */
export const TOKEN_TTL_DAYS = 14;
const TOKEN_TTL_MS = TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000;

/**
 * The unambiguous token alphabet (no 0/O/1/l/I) — mirrors the Dart
 * `DeepLinkInviteService._tokenChars`. Keep the two in sync.
 */
const TOKEN_CHARS =
  'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
const TOKEN_LENGTH = 20;

/** Mints a crypto-random 20-char token (the future doc id). */
const mintToken = () =>
  Array.from(
    { length: TOKEN_LENGTH },
    () => TOKEN_CHARS[randomInt(TOKEN_CHARS.length)],
  ).join('');

/**
 * The shareable link format — mirrors the Dart `InviteDeepLinks.buildUri`
 * (`https://duet.app/invite/<token>`). Keep the two in sync: the app's deep
 * link parser only recognizes this shape.
 */
const inviteUrlFor = (token: string) => `https://duet.app/invite/${token}`;

/** Machine-readable denial reasons, carried in `HttpsError.details.reason`. */
export type InviteTokenErrorReason =
  | 'invalid'
  | 'expired'
  | 'consumed'
  | 'at-cap'
  | 'already-collaborator';

// User-facing copy, mirroring the Dart mock path (`DeepLinkInviteService`)
// so both impls surface identical strings.
const INVALID_MESSAGE = 'This invite link is invalid or has expired.';
const CONSUMED_MESSAGE = 'This invite has already been used.';
const AT_CAP_MESSAGE =
  'Free plan allows 1 collaborator. Upgrade to invite more.';
const ALREADY_COLLABORATOR_MESSAGE = 'You already have access to this piece.';

const inviteTokenError = (
  code: FunctionsErrorCode,
  reason: InviteTokenErrorReason,
  message: string,
) => new HttpsError(code, message, { reason });

interface InviteTokenDoc {
  pieceId?: string;
  ownerId?: string;
  ownerName?: string | null;
  createdAt?: Timestamp;
  expiresAt?: Timestamp;
  consumed?: boolean;
  consumedBy?: string | null;
}

interface PieceDoc {
  ownerId?: string;
  ownerName?: string | null;
  title?: string;
  participantIds?: string[];
  collaborators?: unknown[];
}

/**
 * Validates a token snapshot for [uid]: it must exist, not be consumed by
 * someone else, and not be expired. A token the caller *themself* consumed
 * stays resolvable (and re-acceptance then reports `already-collaborator`),
 * so re-opening a redeemed link lands on the friendly "you already have
 * access" screen instead of a dead "already used" error.
 */
function requireRedeemableBy(
  uid: string,
  snap: DocumentSnapshot,
): InviteTokenDoc {
  if (!snap.exists) {
    throw inviteTokenError('not-found', 'invalid', INVALID_MESSAGE);
  }
  const invite = snap.data() as InviteTokenDoc;
  const consumedBySelf = invite.consumed === true && invite.consumedBy === uid;
  if (invite.consumed === true && !consumedBySelf) {
    throw inviteTokenError('failed-precondition', 'consumed', CONSUMED_MESSAGE);
  }
  // A missing `expiresAt` counts as expired — defensive, a well-formed doc
  // always has one. Skipped for a self-consumed token (it was redeemed while
  // valid; expiry afterwards must not hide the already-a-collaborator state).
  if (
    !consumedBySelf &&
    (invite.expiresAt?.toMillis() ?? 0) <= Date.now()
  ) {
    throw inviteTokenError('failed-precondition', 'expired', INVALID_MESSAGE);
  }
  if (typeof invite.pieceId !== 'string' || invite.pieceId.length === 0) {
    throw inviteTokenError('not-found', 'invalid', INVALID_MESSAGE);
  }
  return invite;
}

interface CreateInviteTokenData {
  pieceId?: unknown;
}

/**
 * Mints a single-use, expiring invite token for a piece the caller owns and
 * returns the shareable URL. Owner-only; re-asserts the per-piece
 * collaborator cap (`at-cap`) so an at-cap owner can't stockpile links.
 */
export const createInviteToken = onCall({ region: REGION }, async (request) => {
  if (request.auth == null) {
    throw new HttpsError('unauthenticated', 'Sign in to create an invite.');
  }
  const { pieceId } = (request.data ?? {}) as CreateInviteTokenData;
  if (typeof pieceId !== 'string' || pieceId.length === 0) {
    throw new HttpsError('invalid-argument', 'A pieceId is required.');
  }

  const ownerId = request.auth.uid;
  const firestore = db();
  const pieceSnap = await firestore.doc(`pieces/${pieceId}`).get();
  if (!pieceSnap.exists) {
    throw new HttpsError('not-found', 'That piece no longer exists.');
  }
  const piece = pieceSnap.data() as PieceDoc;
  if (piece.ownerId !== ownerId) {
    throw new HttpsError(
      'permission-denied',
      'Only the owner of a piece can invite collaborators.',
    );
  }
  const cap = capFor(await ownerIsPro(ownerId));
  if ((piece.collaborators ?? []).length >= cap) {
    throw inviteTokenError('resource-exhausted', 'at-cap', AT_CAP_MESSAGE);
  }

  const ownerName =
    (request.auth.token.name as string | undefined) ??
    piece.ownerName ??
    null;
  const token = mintToken();
  const now = Timestamp.now();
  const expiresAt = Timestamp.fromMillis(now.toMillis() + TOKEN_TTL_MS);
  // `create` (not `set`): a doc-id collision — astronomically unlikely at
  // 57^20 — must fail loudly rather than silently recycle a live token.
  await firestore.doc(`inviteTokens/${token}`).create({
    pieceId,
    ownerId,
    ownerName,
    createdAt: now,
    expiresAt,
    consumed: false,
    consumedBy: null,
  });

  logger.info('createInviteToken: minted', { ownerId, pieceId });
  return {
    status: 'created' as const,
    token,
    url: inviteUrlFor(token),
    expiresAtMillis: expiresAt.toMillis(),
  };
});

interface ResolveInviteTokenData {
  token?: unknown;
}

/**
 * Read-only preview for the Accept Invite screen: resolves a redeemable
 * token to the piece title + owner, without consuming anything. Kept as its
 * own callable (rather than a first phase of `acceptInviteToken`) so that
 * merely opening an invite link can never mutate state, and so the client
 * can render the "join <title>?" screen before the user commits.
 */
export const resolveInviteToken = onCall(
  { region: REGION },
  async (request) => {
    if (request.auth == null) {
      throw new HttpsError('unauthenticated', 'Sign in to view an invite.');
    }
    const { token } = (request.data ?? {}) as ResolveInviteTokenData;
    if (typeof token !== 'string' || token.length === 0) {
      throw new HttpsError('invalid-argument', 'A token is required.');
    }

    const uid = request.auth.uid;
    const firestore = db();
    const invite = requireRedeemableBy(
      uid,
      await firestore.doc(`inviteTokens/${token}`).get(),
    );
    const pieceSnap = await firestore.doc(`pieces/${invite.pieceId}`).get();
    if (!pieceSnap.exists) {
      // The piece was deleted after minting; the token is dead.
      throw inviteTokenError('not-found', 'invalid', INVALID_MESSAGE);
    }
    const piece = pieceSnap.data() as PieceDoc;
    return {
      status: 'resolved' as const,
      pieceId: invite.pieceId,
      pieceTitle: piece.title ?? '',
      ownerId: invite.ownerId ?? null,
      ownerName: invite.ownerName ?? piece.ownerName ?? null,
    };
  },
);

interface AcceptInviteTokenData {
  token?: unknown;
  accepterName?: unknown;
  accepterEmail?: unknown;
}

/**
 * Redeems an invite token, transactionally: exists ∧ !consumed ∧ !expired →
 * append the caller to `pieces/{id}.participantIds` + `collaborators` →
 * mark the token `consumed`/`consumedBy`. The single transaction is what
 * makes the token single-use under concurrency: two racing accepts contend
 * on the token doc, and the loser retries into the `consumed` denial.
 *
 * The per-piece cap is enforced against the owner's tier from
 * `entitlements/{ownerId}` (read in the same transaction; absent = free
 * tier until M6.3 populates it — see `collaboratorLimits.ts`).
 */
export const acceptInviteToken = onCall({ region: REGION }, async (request) => {
  if (request.auth == null) {
    throw new HttpsError('unauthenticated', 'Sign in to accept an invite.');
  }
  const { token, accepterName, accepterEmail } = (request.data ??
    {}) as AcceptInviteTokenData;
  if (typeof token !== 'string' || token.length === 0) {
    throw new HttpsError('invalid-argument', 'A token is required.');
  }

  const uid = request.auth.uid;
  const name =
    typeof accepterName === 'string'
      ? accepterName
      : ((request.auth.token.name as string | undefined) ?? null);
  const email =
    typeof accepterEmail === 'string'
      ? accepterEmail
      : ((request.auth.token.email as string | undefined) ?? null);

  const firestore = db();
  const tokenRef = firestore.doc(`inviteTokens/${token}`);
  const result = await firestore.runTransaction(async (tx) => {
    const invite = requireRedeemableBy(uid, await tx.get(tokenRef));
    const pieceRef = firestore.doc(`pieces/${invite.pieceId}`);
    const pieceSnap = await tx.get(pieceRef);
    if (!pieceSnap.exists) {
      throw inviteTokenError('not-found', 'invalid', INVALID_MESSAGE);
    }
    const piece = pieceSnap.data() as PieceDoc;
    const participantIds = piece.participantIds ?? [];
    if (participantIds.includes(uid)) {
      // Covers both the owner opening their own link and a collaborator
      // re-opening the link they already redeemed.
      throw inviteTokenError(
        'already-exists',
        'already-collaborator',
        ALREADY_COLLABORATOR_MESSAGE,
      );
    }
    const entitlement = await tx.get(
      firestore.doc(`entitlements/${invite.ownerId}`),
    );
    const cap = capFor(entitlement.data()?.pro === true);
    const collaborators = piece.collaborators ?? [];
    if (collaborators.length >= cap) {
      throw inviteTokenError('resource-exhausted', 'at-cap', AT_CAP_MESSAGE);
    }
    tx.update(pieceRef, {
      participantIds: [...participantIds, uid],
      collaborators: [...collaborators, { uid, name, email }],
      // Backfill the owner's display name onto a piece that predates the
      // field, exactly as the local `pairCollaborator` seam does.
      ...(piece.ownerName == null && invite.ownerName != null
        ? { ownerName: invite.ownerName }
        : {}),
    });
    tx.update(tokenRef, { consumed: true, consumedBy: uid });
    return { pieceId: invite.pieceId, ownerId: invite.ownerId ?? null };
  });

  logger.info('acceptInviteToken: consumed', { uid, pieceId: result.pieceId });
  return { status: 'accepted' as const, ...result };
});
