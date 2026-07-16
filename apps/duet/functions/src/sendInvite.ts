import * as logger from 'firebase-functions/logger';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from './firebase';
import { REGION } from './region';

/** The `data.type` marking an invite message (mirrors the Dart client). */
const INVITE_TYPE = 'invite';

/** Lower-cases + trims an email to the `usersByEmail` document key. */
const emailKey = (email: string) => email.trim().toLowerCase();

interface SendInviteData {
  pieceId?: unknown;
  inviteeEmail?: unknown;
}

/**
 * Sends a collaborator invite to a discoverable account's inbox (task M2.4).
 *
 * This is the server-authoritative replacement for the client's former direct
 * `userInbox` write: under the M2.2 rules clients can no longer create inbox
 * documents (`create: if false`), closing v1 risk #1 (inbox spam) — only this
 * callable, via the Admin SDK, writes them, and only to a resolved,
 * *discoverable* recipient.
 *
 * The caller must own `pieceId`, verified against the piece document (M3.6,
 * now that pieces live in Firestore). The per-piece collaborator cap is
 * re-checked on *accept*, not here — enforcing it needs the owner's pro tier,
 * which isn't knowable server-side until M6.3 (see `collaboratorLimits.ts`).
 * The inbox-authorization guarantee (only this callable writes an inbox doc,
 * only to a discoverable recipient) is unchanged.
 */
export const sendInvite = onCall({ region: REGION }, async (request) => {
  if (request.auth == null) {
    throw new HttpsError('unauthenticated', 'Sign in to send an invite.');
  }
  const { pieceId, inviteeEmail } = (request.data ?? {}) as SendInviteData;
  if (typeof pieceId !== 'string' || pieceId.length === 0) {
    throw new HttpsError('invalid-argument', 'A pieceId is required.');
  }
  if (typeof inviteeEmail !== 'string' || inviteeEmail.length === 0) {
    throw new HttpsError('invalid-argument', 'An inviteeEmail is required.');
  }

  const ownerId = request.auth.uid;
  const firestore = db();

  // Verify the caller owns `pieceId` before inviting anyone to it — now that
  // pieces live in Firestore (M3) this replaces the pre-M3 placeholder that
  // trusted the caller. (The collaborator cap is re-checked on accept; it
  // needs the owner's pro tier, unknowable server-side until M6.3.)
  const pieceSnap = await firestore.doc(`pieces/${pieceId}`).get();
  if (!pieceSnap.exists) {
    throw new HttpsError('not-found', 'That piece no longer exists.');
  }
  if (pieceSnap.data()?.ownerId !== ownerId) {
    throw new HttpsError(
      'permission-denied',
      'Only the owner of a piece can invite collaborators.',
    );
  }

  // Resolve the invitee exactly as `FirestoreUserDirectory.lookupByEmail`
  // does — an exact-key GET gated on the target's own `discoverable` flag, so
  // a hidden or absent account is indistinguishable (no enumeration).
  const entry = (
    await firestore.doc(`usersByEmail/${emailKey(inviteeEmail)}`).get()
  ).data();
  if (entry == null || entry.discoverable !== true) {
    return { status: 'no-account' as const };
  }
  const recipientUid = entry.uid as string;

  // The owner's display name rides on their own ID token — no extra read.
  const ownerName = (request.auth.token.name as string | undefined) ?? null;

  const messageId = firestore.collection('_ids').doc().id;
  await firestore.doc(`userInbox/${recipientUid}/messages/${messageId}`).set({
    toUid: recipientUid,
    title: `${ownerName ?? 'Someone'} invited you to collaborate`,
    body: 'Join a shared piece on Duet.',
    data: { type: INVITE_TYPE, pieceId, ownerId, ownerName: ownerName ?? '' },
    sentAtMillis: Date.now(),
    read: false,
    // An invite is consumed by `acceptInvite`, never by being displayed. The
    // client's inbox->notification bridge keys off this to leave it unread;
    // without it the invite is burned the moment the recipient is notified,
    // and every accept then fails as already-used.
    requiresAction: true,
  });

  logger.info('sendInvite: delivered', { ownerId, recipientUid, pieceId });
  return {
    status: 'sent' as const,
    messageId,
    recipientUid,
    recipientEmail: entry.email as string,
    recipientDisplayName: (entry.displayName as string | undefined) ?? null,
  };
});
