import * as logger from 'firebase-functions/logger';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from './firebase';
import { REGION } from './region';

/** The `data.type` marking a nudge message (mirrors the Dart client). */
const NUDGE_TYPE = 'nudge';

interface SendNudgeData {
  pieceId?: unknown;
}

/**
 * Nudges a piece's *other* participants — a lightweight "I added notes" ping,
 * distinct from an access-granting invite (task M4.2).
 *
 * Server-authoritative for the same reason as `sendInvite`: under the M2.2
 * rules clients can't create `userInbox` documents, so only this callable (via
 * the Admin SDK) delivers a nudge — and only after verifying the caller is
 * actually a participant on the piece, so a nudge can only reach people you
 * already share the sheet with (no inbox spam). Delivery is the foreground
 * inbox bridge until FCM push lands (M5.3); the payload shape is unchanged
 * then, and tap-through routing to the piece lands in M5.5.
 */
export const sendNudge = onCall({ region: REGION }, async (request) => {
  if (request.auth == null) {
    throw new HttpsError('unauthenticated', 'Sign in to nudge a collaborator.');
  }
  const { pieceId } = (request.data ?? {}) as SendNudgeData;
  if (typeof pieceId !== 'string' || pieceId.length === 0) {
    throw new HttpsError('invalid-argument', 'A pieceId is required.');
  }

  const senderId = request.auth.uid;
  const firestore = db();

  const pieceSnap = await firestore.doc(`pieces/${pieceId}`).get();
  if (!pieceSnap.exists) {
    throw new HttpsError('not-found', 'That piece no longer exists.');
  }
  const participantIds = (pieceSnap.data()?.participantIds ?? []) as string[];
  if (!participantIds.includes(senderId)) {
    throw new HttpsError(
      'permission-denied',
      'Only a participant on a piece can nudge its collaborators.',
    );
  }

  // The sender's display name rides on their own ID token — no extra read, and
  // not trusting a client-supplied name.
  const fromName = (request.auth.token.name as string | undefined) ?? 'Someone';
  const recipients = participantIds.filter((uid) => uid !== senderId);

  const batch = firestore.batch();
  for (const recipientUid of recipients) {
    const messageId = firestore.collection('_ids').doc().id;
    batch.set(
      firestore.doc(`userInbox/${recipientUid}/messages/${messageId}`),
      {
        toUid: recipientUid,
        title: `${fromName} added notes`,
        body: 'Open the sheet to see what changed.',
        data: { type: NUDGE_TYPE, pieceId, fromName },
        sentAtMillis: Date.now(),
        read: false,
      },
    );
  }
  await batch.commit();

  logger.info('sendNudge: delivered', {
    senderId,
    pieceId,
    recipientCount: recipients.length,
  });
  return { status: 'sent' as const, recipientCount: recipients.length };
});
