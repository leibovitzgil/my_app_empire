import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import { db } from '../src/firebase';
import { sweepTombstonesBefore } from '../src/gcTombstones';

// Emulator-backed (Firestore only). `--only auth,firestore` doesn't configure a
// Storage bucket, so the best-effort audio-object delete is skipped here (the
// emulator E2E covers it); the Firestore hard-delete is what this asserts. We
// drive the sweep with an explicit cutoff rather than wall-clock time.
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

const CUTOFF = new Date('2024-02-01T00:00:00Z');

const note = (fields: Record<string, unknown>) => ({
  authorId: 'uid-a',
  audioAssetId: 'asset-x',
  pageIndex: 0,
  durationMs: 1000,
  region: { pageIndex: 0, left: 0, top: 0, width: 1, height: 1 },
  createdAt: Timestamp.fromDate(new Date('2024-01-01T00:00:00Z')),
  deletedAt: null,
  ...fields,
});

const at = (iso: string) => Timestamp.fromDate(new Date(iso));

describe('gcTombstones (sweepTombstonesBefore)', () => {
  beforeEach(clearFirestore, TIMEOUT);

  it(
    'hard-deletes tombstones at/before the cutoff, keeping fresh tombstones ' +
      'and live notes',
    { timeout: TIMEOUT },
    async () => {
      // Expired: tombstoned before the cutoff — reclaimable.
      await db()
        .doc('pieces/p1/notes/expired')
        .set(note({ deletedAt: at('2024-01-01T00:00:00Z') }));
      // Fresh: tombstoned after the cutoff — still inside the retention window.
      await db()
        .doc('pieces/p1/notes/fresh')
        .set(note({ deletedAt: at('2024-02-15T00:00:00Z') }));
      // Live: never deleted (explicit `deletedAt: null`) — must survive, even
      // though null sorts before every timestamp in the range filter.
      await db().doc('pieces/p1/notes/live').set(note({ deletedAt: null }));

      const swept = await sweepTombstonesBefore(CUTOFF);

      expect(swept).toBe(1);
      expect((await db().doc('pieces/p1/notes/expired').get()).exists).toBe(
        false,
      );
      expect((await db().doc('pieces/p1/notes/fresh').get()).exists).toBe(true);
      expect((await db().doc('pieces/p1/notes/live').get()).exists).toBe(true);
    },
  );

  it(
    'sweeps expired tombstones across every piece (collection group)',
    { timeout: TIMEOUT },
    async () => {
      await db()
        .doc('pieces/p1/notes/n1')
        .set(note({ deletedAt: at('2023-12-01T00:00:00Z') }));
      await db()
        .doc('pieces/p2/notes/n2')
        .set(note({ deletedAt: at('2023-12-01T00:00:00Z') }));

      const swept = await sweepTombstonesBefore(CUTOFF);

      expect(swept).toBe(2);
      expect((await db().collection('pieces/p1/notes').get()).empty).toBe(true);
      expect((await db().collection('pieces/p2/notes').get()).empty).toBe(true);
    },
  );
});
