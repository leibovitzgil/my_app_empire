import * as logger from 'firebase-functions/logger';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { adminAuth, bucket, db } from './firebase';
import { REGION } from './region';

/**
 * How recently the caller must have signed in. The client re-authenticates
 * first (feature_auth's ReauthDialog, task M1.4), so a legitimate deletion
 * always arrives well inside this window.
 */
const MAX_AUTH_AGE_SECONDS = 5 * 60;

/** What one purge pass actually deleted (also the callable's payload). */
interface PurgeSummary {
  directoryEntries: number;
  deviceTokens: number;
  inboxMessages: number;
  ownedPieces: number;
  leftPieces: number;
}

/**
 * Server-authoritative account deletion (task M1.8).
 *
 * Purges everything the calling uid owns in Firestore, then deletes the
 * Auth user itself. A callable — not a client-side cascade — because the
 * rules (correctly) scope clients to their own docs one at a time, v2 has
 * no Auth onDelete trigger, and doing it synchronously gives the client a
 * definitive answer.
 *
 * Purge order (each step idempotent, so a retry after a partial failure
 * just deletes whatever is left):
 *
 * 1. `usersByEmail` docs found by `where uid ==` — the doc id is an email
 *    key and may not be the account's *current* address, so never derive
 *    it from the token.
 * 2. `deviceTokens/{uid}`.
 * 3. `userInbox/{uid}` recursively (the messages subcollection lives
 *    under a parent doc that never exists as a document).
 * 4. Pieces (M3.8): owned pieces are deleted whole (the `onPieceDeleted`
 *    trigger cascades their subcollections + Storage); pieces the caller only
 *    collaborated on lose the caller from `participantIds`/`collaborators`
 *    plus the slice they authored (layer doc, notes, Storage audio objects).
 * 5. The Auth user, last — if any purge step fails, the account survives
 *    to retry.
 */
// TODO(M0.3): add `enforceAppCheck: true` once App Check is enforced.
export const deleteAccount = onCall({ region: REGION }, async (request) => {
  if (request.auth == null) {
    throw new HttpsError(
      'unauthenticated',
      'Account deletion requires a signed-in caller.',
    );
  }
  const uid = request.auth.uid;

  // Deleting an account is the most destructive thing a stolen session can
  // do, so require a *recent* sign-in, not just a valid token.
  const authAge = Date.now() / 1000 - request.auth.token.auth_time;
  if (authAge > MAX_AUTH_AGE_SECONDS) {
    throw new HttpsError(
      'failed-precondition',
      'Account deletion requires a recent sign-in. ' +
        'Re-authenticate and try again.',
    );
  }

  const firestore = db();

  const directory = await firestore
    .collection('usersByEmail')
    .where('uid', '==', uid)
    .get();
  const tokenRef = firestore.doc(`deviceTokens/${uid}`);
  // Read before the blind delete purely so the summary reports honestly.
  const hadTokenDoc = (await tokenRef.get()).exists;

  const writer = firestore.bulkWriter();
  for (const entry of directory.docs) {
    void writer.delete(entry.ref);
  }
  void writer.delete(tokenRef);
  await writer.close();

  const inboxCount = (
    await firestore.collection(`userInbox/${uid}/messages`).count().get()
  ).data().count;
  await firestore.recursiveDelete(firestore.doc(`userInbox/${uid}`));

  // M3.8: the caller's pieces. One query gets every piece they participate in
  // (owner or collaborator); owned ones are deleted whole (the onPieceDeleted
  // trigger cascades their subcollections + Storage), and for the rest the
  // caller is removed from the participant arrays and the slice they authored
  // (their layer doc, their notes, and each note's Storage audio object).
  const myPieces = await firestore
    .collection('pieces')
    .where('participantIds', 'array-contains', uid)
    .get();

  let storageBucket: ReturnType<typeof bucket> | null = null;
  try {
    storageBucket = bucket();
  } catch {
    // No bucket configured (unit test) — Storage cleanup is skipped; the
    // Firestore side is still fully purged.
    storageBucket = null;
  }

  const pieceWriter = firestore.bulkWriter();
  let ownedPieces = 0;
  let leftPieces = 0;
  for (const doc of myPieces.docs) {
    if (doc.data().ownerId === uid) {
      void pieceWriter.delete(doc.ref); // onPieceDeleted cascades the rest
      ownedPieces++;
    }
  }
  await pieceWriter.close();

  for (const doc of myPieces.docs) {
    if (doc.data().ownerId === uid) continue;
    leftPieces++;
    const pieceId = doc.id;
    const notes = await firestore
      .collection(`pieces/${pieceId}/notes`)
      .where('authorId', '==', uid)
      .get();
    // Delete the caller's audio objects (keyed by each note's assetId).
    if (storageBucket != null) {
      for (const note of notes.docs) {
        const assetId = note.data().audioAssetId as unknown;
        if (typeof assetId !== 'string') continue;
        await storageBucket
          .file(`pieces/${pieceId}/audio/${assetId}`)
          .delete({ ignoreNotFound: true })
          .catch((err: unknown) =>
            logger.warn('deleteAccount: audio cleanup skipped', {
              pieceId,
              assetId,
              err,
            }),
          );
      }
    }
    // Delete their authored layer + notes, then drop them from the arrays.
    const sliceWriter = firestore.bulkWriter();
    void sliceWriter.delete(firestore.doc(`pieces/${pieceId}/layers/${uid}`));
    for (const note of notes.docs) {
      void sliceWriter.delete(note.ref);
    }
    await sliceWriter.close();
    await firestore.runTransaction(async (tx) => {
      const snap = await tx.get(doc.ref);
      if (!snap.exists) return;
      const piece = snap.data() as {
        participantIds?: string[];
        collaborators?: { uid?: string }[];
      };
      tx.update(doc.ref, {
        participantIds: (piece.participantIds ?? []).filter((id) => id !== uid),
        collaborators: (piece.collaborators ?? []).filter((c) => c.uid !== uid),
      });
    });
  }

  try {
    await adminAuth().deleteUser(uid);
  } catch (e) {
    // Already gone — a retry after a partial earlier run. Everything above
    // is idempotent, so finishing the purge is the right outcome.
    if ((e as { code?: string }).code !== 'auth/user-not-found') throw e;
  }

  const summary: PurgeSummary = {
    directoryEntries: directory.size,
    deviceTokens: hadTokenDoc ? 1 : 0,
    inboxMessages: inboxCount,
    ownedPieces,
    leftPieces,
  };
  // The audit record lives in Cloud Logging: uid and counts only — email
  // addresses (the directory doc ids) deliberately stay out of the logs.
  logger.info('deleteAccount: purge complete', { uid, ...summary });
  return { status: 'deleted', ...summary };
});
