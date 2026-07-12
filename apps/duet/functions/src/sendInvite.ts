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
 * Pre-M3 (no `pieces` collection yet) the server can't verify the caller owns
 * `pieceId`, nor count existing collaborators for the cap — both need the
 * piece document. It therefore records the caller as the owner and defers
 * those checks with `// M3.6` markers; the inbox-authorization guarantee is
 * already fully real.
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
  // M3.6: verify the caller owns `pieceId` (read the piece doc), and count
  // pieces/{id}.collaborators against capFor(isPro) — neither is possible
  // until the pieces collection exists (M3).

  const firestore = db();

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
