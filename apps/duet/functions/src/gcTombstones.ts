import { Timestamp } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { bucket, db } from './firebase';
import { REGION } from './region';

/**
 * How long a tombstoned (soft-deleted) audio note is retained before the daily
 * GC hard-deletes it. A delete tombstones rather than physically removing the
 * note (M4.4) so it converges across offline peers instead of resurrecting;
 * once every peer has had ample time to observe the tombstone, it can be
 * reclaimed.
 */
export const TOMBSTONE_RETENTION_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * Hard-deletes every tombstoned audio note whose `deletedAt` is at or before
 * [cutoff] — the note document and its Cloud Storage audio object. A
 * collection-group query spans every piece's `notes` subcollection in one
 * pass. Returns the number of notes swept.
 *
 * Storage deletion is best-effort (mirrors `onPieceDeleted`'s cascade): a
 * missing object or an unconfigured bucket in a unit test is logged and
 * skipped, never fatal — the Firestore delete is the part the functions test
 * covers. Split out from [gcTombstones] so the test can drive it with an
 * explicit cutoff instead of wall-clock time.
 */
export async function sweepTombstonesBefore(cutoff: Date): Promise<number> {
  const snapshot = await db()
    .collectionGroup('notes')
    .where('deletedAt', '<=', Timestamp.fromDate(cutoff))
    .get();
  let deleted = 0;
  for (const doc of snapshot.docs) {
    // A live note carries an explicit `deletedAt: null`. Whether a range
    // filter surfaces null is Firestore-version/emulator dependent (null sorts
    // before every timestamp), so re-check the type and never hard-delete a
    // note that isn't actually a tombstone regardless of what the query returns.
    const deletedAt = doc.get('deletedAt');
    if (!(deletedAt instanceof Timestamp)) continue;
    const pieceId = doc.ref.parent.parent?.id;
    const { audioAssetId } = doc.data() as { audioAssetId?: string };
    if (pieceId && audioAssetId) {
      try {
        await bucket()
          .file(`pieces/${pieceId}/audio/${audioAssetId}`)
          .delete({ ignoreNotFound: true });
      } catch (err) {
        logger.warn('gcTombstones: storage cleanup skipped', {
          pieceId,
          audioAssetId,
          err,
        });
      }
    }
    await doc.ref.delete();
    deleted += 1;
  }
  return deleted;
}

/**
 * Daily sweep of expired audio-note tombstones (M4.4). Reclaims soft-deleted
 * notes older than [TOMBSTONE_RETENTION_MS] — hard-deleting the doc and its
 * audio object — so tombstones don't accumulate without bound once they've
 * served their convergence purpose.
 */
export const gcTombstones = onSchedule(
  { region: REGION, schedule: 'every 24 hours' },
  async () => {
    const cutoff = new Date(Date.now() - TOMBSTONE_RETENTION_MS);
    const deleted = await sweepTombstonesBefore(cutoff);
    logger.info('gcTombstones swept expired tombstones', { deleted });
  },
);
