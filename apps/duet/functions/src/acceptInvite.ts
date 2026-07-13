import * as logger from 'firebase-functions/logger';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from './firebase';
import { REGION } from './region';

const INVITE_TYPE = 'invite';

interface AcceptInviteData {
  messageId?: unknown;
  accepterName?: unknown;
  accepterEmail?: unknown;
}

/**
 * Authorizes and consumes a collaborator invite (task M2.4).
 *
 * Under the M2.2 rules a client can no longer add itself to another user's
 * piece, so acceptance must be server-authoritative. The message must exist in
 * the caller's own inbox, be addressed to them, be an `invite`, and be unread;
 * this callable marks it read (consumed) so it can't be replayed.
 *
 * Now that pieces live in Firestore (M3.8), it also **adds the caller to the
 * piece** transactionally — appending their uid to `participantIds` and a
 * `{uid, name, email}` entry to `collaborators`, idempotently — which is what
 * lets the collaborator's `watchPieces` (a `participantIds array-contains`
 * query) actually see the sheet. The per-piece collaborator **cap** stays
 * deferred to M6.3: enforcing it needs the *owner's* pro tier, which isn't
 * knowable server-side yet (see `collaboratorLimits.ts`).
 */
export const acceptInvite = onCall({ region: REGION }, async (request) => {
  if (request.auth == null) {
    throw new HttpsError('unauthenticated', 'Sign in to accept an invite.');
  }
  const { messageId, accepterName, accepterEmail } = (request.data ??
    {}) as AcceptInviteData;
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

  // Add the caller to the piece transactionally (server-authoritative: the
  // rules make participantIds immutable to clients). Idempotent — re-accepting
  // a piece the caller already joined is a no-op — and done before marking the
  // message read, so a failure here leaves the invite replayable.
  const pieceId = message.data?.pieceId;
  if (typeof pieceId === 'string' && pieceId.length > 0) {
    const name =
      typeof accepterName === 'string'
        ? accepterName
        : ((request.auth.token.name as string | undefined) ?? null);
    const email =
      typeof accepterEmail === 'string'
        ? accepterEmail
        : ((request.auth.token.email as string | undefined) ?? null);
    const pieceRef = firestore.doc(`pieces/${pieceId}`);
    await firestore.runTransaction(async (tx) => {
      const pieceSnap = await tx.get(pieceRef);
      if (!pieceSnap.exists) return; // the piece was deleted; nothing to join
      const piece = pieceSnap.data() as {
        participantIds?: string[];
        collaborators?: unknown[];
      };
      const participantIds = piece.participantIds ?? [];
      if (participantIds.includes(uid)) return; // already a participant
      // M6.3: enforce the per-piece cap here (needs the owner's pro tier).
      tx.update(pieceRef, {
        participantIds: [...participantIds, uid],
        collaborators: [...(piece.collaborators ?? []), { uid, name, email }],
      });
    });
  }

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
