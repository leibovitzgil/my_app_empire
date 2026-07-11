import * as logger from 'firebase-functions/logger';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { adminAuth, db } from './firebase';
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
 * 4. The Auth user, last — if any purge step fails, the account survives
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

  // M3.8 extends: pieces, layers, notes, storage.

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
  };
  // The audit record lives in Cloud Logging: uid and counts only — email
  // addresses (the directory doc ids) deliberately stay out of the logs.
  logger.info('deleteAccount: purge complete', { uid, ...summary });
  return { status: 'deleted', ...summary };
});
