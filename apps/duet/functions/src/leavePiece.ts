import * as logger from 'firebase-functions/logger';
import { FieldValue } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from './firebase';
import { REGION } from './region';

interface LeavePieceData {
  pieceId?: unknown;
}

/**
 * Removes the caller from a piece they collaborate on (task M2.4).
 *
 * Server-authoritative because the M2.2 rules make `participantIds` immutable
 * to clients. Pre-M3 there is no `pieces` document, so this is a no-op success
 * (the local on-device `PieceRepository.leavePiece` handles the client state);
 * it is written doc-guarded so it becomes correct automatically once M3 lands
 * the piece collection.
 */
export const leavePiece = onCall({ region: REGION }, async (request) => {
  if (request.auth == null) {
    throw new HttpsError('unauthenticated', 'Sign in to leave a piece.');
  }
  const { pieceId } = (request.data ?? {}) as LeavePieceData;
  if (typeof pieceId !== 'string' || pieceId.length === 0) {
    throw new HttpsError('invalid-argument', 'A pieceId is required.');
  }

  const uid = request.auth.uid;
  const firestore = db();
  const pieceRef = firestore.doc(`pieces/${pieceId}`);
  const piece = await pieceRef.get();

  if (!piece.exists) {
    // Pre-M3: nothing server-side to remove yet.
    return { status: 'left' as const, removed: false };
  }

  const data = piece.data() as {
    ownerId?: string;
    collaborators?: Array<{ uid: string }>;
  };
  if (data.ownerId === uid) {
    throw new HttpsError(
      'failed-precondition',
      'An owner cannot leave their own piece; delete it instead.',
    );
  }

  const collaborators = (data.collaborators ?? []).filter((c) => c.uid !== uid);
  await pieceRef.update({
    collaborators,
    participantIds: FieldValue.arrayRemove(uid),
  });
  // Drop the caller's own annotation layer; their notes are left tombstoned by
  // the client (M4.4) rather than hard-deleted here.
  await firestore.doc(`pieces/${pieceId}/layers/${uid}`).delete();

  logger.info('leavePiece: removed', { uid, pieceId });
  return { status: 'left' as const, removed: true };
});
