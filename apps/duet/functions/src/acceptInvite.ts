import * as logger from 'firebase-functions/logger';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from './firebase';
import { REGION } from './region';

const INVITE_TYPE = 'invite';

interface AcceptInviteData {
  messageId?: unknown;
}

/**
 * Authorizes and consumes a collaborator invite (task M2.4).
 *
 * Under the M2.2 rules a client can no longer add itself to another user's
 * piece, so acceptance must be server-authoritative. The message must exist in
 * the caller's own inbox, be addressed to them, be an `invite`, and be unread;
 * this callable marks it read (consumed) so it can't be replayed.
 *
 * Pre-M3 there is no `pieces` document to mutate, so the participant-array
 * write lives client-side (the piece is on-device) and this callable only
 * verifies + consumes the message. Post-M3 (`// M3.6`) it additionally adds
 * the caller to `pieces/{id}.participantIds`/`collaborators` transactionally
 * and re-checks the cap.
 */
export const acceptInvite = onCall({ region: REGION }, async (request) => {
  if (request.auth == null) {
    throw new HttpsError('unauthenticated', 'Sign in to accept an invite.');
  }
  const { messageId } = (request.data ?? {}) as AcceptInviteData;
  if (typeof messageId !== 'string' || messageId.length === 0) {
    throw new HttpsError('invalid-argument', 'A messageId is required.');
  }

  const uid = request.auth.uid;
  const firestore = db();
  const ref = firestore.doc(`userInbox/${uid}/messages/${messageId}`);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'That invite no longer exists.');
  }
  const message = snap.data() as {
    toUid?: string;
    read?: boolean;
    data?: { type?: string; pieceId?: string; ownerId?: string };
  };
  // The path already scopes to the caller's inbox; assert toUid too, defence
  // in depth against a mis-seeded document.
  if (message.toUid !== uid || message.data?.type !== INVITE_TYPE) {
    throw new HttpsError('failed-precondition', 'Not an invite for you.');
  }
  if (message.read === true) {
    throw new HttpsError('failed-precondition', 'That invite was already used.');
  }

  // M3.6: re-check the cap against pieces/{pieceId}.collaborators and add
  // `uid` to participantIds + collaborators in a transaction. Pre-M3 the
  // piece is on-device, so the client performs that mutation.

  await ref.set({ read: true }, { merge: true });

  logger.info('acceptInvite: consumed', {
    uid,
    pieceId: message.data?.pieceId,
  });
  return {
    status: 'accepted' as const,
    pieceId: message.data?.pieceId ?? null,
    ownerId: message.data?.ownerId ?? null,
  };
});
