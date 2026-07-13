import * as logger from 'firebase-functions/logger';
import { onDocumentDeleted } from 'firebase-functions/v2/firestore';

import { bucket, db } from './firebase';
import { REGION } from './region';

/**
 * Cleans up everything a deleted piece leaves behind (M3.8). When a
 * `pieces/{id}` document is deleted (owner-only, per the M2.2 rules) its
 * `layers`/`notes`/`reads` subcollections are orphaned — subcollections
 * survive their parent doc — and its Storage objects
 * (`pieces/{id}/base.pdf` + `pieces/{id}/audio/*`) are unreferenced. This
 * trigger recursively deletes the subcollections and the whole Storage prefix,
 * so no orphans remain.
 *
 * Storage cleanup is best-effort: in a unit test with no bucket configured
 * `bucket()` throws synchronously (caught below, no network call); deployed and
 * on the emulator the prefix delete runs for real. The Firestore cascade is the
 * part covered by the functions test.
 */
export const onPieceDeleted = onDocumentDeleted(
  { region: REGION, document: 'pieces/{pieceId}' },
  async (event) => {
    const { pieceId } = event.params;
    // Subcollections outlive the parent doc, so delete them explicitly.
    await db().recursiveDelete(db().doc(`pieces/${pieceId}`));
    // base.pdf and every audio object live under this one prefix.
    try {
      await bucket().deleteFiles({ prefix: `pieces/${pieceId}/` });
    } catch (err) {
      logger.warn('onPieceDeleted: storage cleanup skipped', { pieceId, err });
    }
  },
);
