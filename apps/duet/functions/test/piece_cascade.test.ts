import { beforeEach, describe, expect, it } from 'vitest';

import { db } from '../src/firebase';
import { onPieceDeleted } from '../src/pieceCascade';

// Emulator-backed (Firestore only). `--only auth,firestore` doesn't start the
// functions emulator, so the trigger doesn't auto-fire on the piece delete —
// we invoke it directly with `.run(event)`. Storage cleanup is best-effort and
// is skipped here (no bucket configured); the emulator E2E covers it.
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.GCLOUD_PROJECT ??= 'demo-duet';
const PROJECT = process.env.GCLOUD_PROJECT;
const TIMEOUT = 20_000;

async function clearFirestore() {
  const res = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/` +
      `${PROJECT}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  if (!res.ok) throw new Error(`clear failed: ${res.status}`);
}

const deletedEvent = (pieceId: string) =>
  ({ params: { pieceId } }) as unknown as Parameters<
    typeof onPieceDeleted.run
  >[0];

describe('onPieceDeleted', () => {
  beforeEach(clearFirestore, TIMEOUT);

  it(
    'recursively deletes the layers/notes/reads subcollections',
    { timeout: TIMEOUT },
    async () => {
      // The piece doc itself is already gone (that's what fires the trigger);
      // its subcollections are orphaned and must be swept.
      await db()
        .doc('pieces/p1/layers/uid-a')
        .set({ ownerId: 'uid-a', strokes: [] });
      await db()
        .doc('pieces/p1/notes/n1')
        .set({ authorId: 'uid-a', audioAssetId: 'x' });
      await db()
        .doc('pieces/p1/reads/uid-a')
        .set({ uid: 'uid-a', lastOpenedAt: new Date() });

      await onPieceDeleted.run(deletedEvent('p1'));

      expect((await db().collection('pieces/p1/layers').get()).empty).toBe(true);
      expect((await db().collection('pieces/p1/notes').get()).empty).toBe(true);
      expect((await db().collection('pieces/p1/reads').get()).empty).toBe(true);
    },
  );

  it(
    'leaves an unrelated piece untouched',
    { timeout: TIMEOUT },
    async () => {
      await db().doc('pieces/p2/layers/uid-a').set({ ownerId: 'uid-a' });

      await onPieceDeleted.run(deletedEvent('p1'));

      expect((await db().collection('pieces/p2/layers').get()).empty).toBe(
        false,
      );
    },
  );
});
