import { beforeEach, describe, expect, it } from 'vitest';

import { db } from '../src/firebase';
import { onLayerWrite, onNoteWrite } from '../src/pieceActivity';

// Emulator-backed (Firestore only). `emulators:exec --only auth,firestore`
// doesn't start the *functions* emulator, so the triggers don't auto-fire on
// writes — we invoke them directly with `.run(event)` (as the callable tests
// do) and assert the effect on the parent piece doc.
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

async function seedPiece() {
  await db().doc('pieces/p1').set({
    ownerId: 'uid-owner',
    title: 'p1',
    participantIds: ['uid-owner', 'uid-collab'],
    updatedAt: new Date('2024-01-01'),
  });
}

async function pieceUpdatedMillis(): Promise<number> {
  const data = (await db().doc('pieces/p1').get()).data();
  return (data?.updatedAt as FirebaseFirestore.Timestamp).toMillis();
}

async function watermark(uid: string) {
  return (await db().doc(`pieces/p1/reads/${uid}`).get()).data();
}

const layerEvent = (pieceId: string, layerId: string, exists: boolean) =>
  ({
    params: { pieceId, layerId },
    data: { after: { exists } },
  }) as unknown as Parameters<typeof onLayerWrite.run>[0];

const noteEvent = (pieceId: string, noteId: string, authorId?: string) =>
  ({
    params: { pieceId, noteId },
    data: {
      after: {
        exists: authorId != null,
        data: () => (authorId == null ? undefined : { authorId }),
      },
    },
  }) as unknown as Parameters<typeof onNoteWrite.run>[0];

describe('onLayerWrite', () => {
  beforeEach(clearFirestore, TIMEOUT);

  it(
    'bumps the piece updatedAt and the editor watermark together',
    { timeout: TIMEOUT },
    async () => {
      await seedPiece();
      const before = await pieceUpdatedMillis();

      await onLayerWrite.run(layerEvent('p1', 'uid-collab', true));

      const after = await pieceUpdatedMillis();
      expect(after).toBeGreaterThan(before);
      // The editor's own watermark advanced to the SAME instant — so the
      // author never sees their own edit as unread, but others do.
      const mark = await watermark('uid-collab');
      expect(mark?.uid).toBe('uid-collab');
      expect((mark?.lastOpenedAt as FirebaseFirestore.Timestamp).toMillis()).toBe(
        after,
      );
    },
  );

  it(
    'ignores a layer removal (no surviving doc)',
    { timeout: TIMEOUT },
    async () => {
      await seedPiece();
      const before = await pieceUpdatedMillis();

      await onLayerWrite.run(layerEvent('p1', 'uid-collab', false));

      expect(await pieceUpdatedMillis()).toBe(before);
      expect(await watermark('uid-collab')).toBeUndefined();
    },
  );
});

describe('onNoteWrite', () => {
  beforeEach(clearFirestore, TIMEOUT);

  it(
    'bumps activity keyed by the note authorId',
    { timeout: TIMEOUT },
    async () => {
      await seedPiece();
      const before = await pieceUpdatedMillis();

      await onNoteWrite.run(noteEvent('p1', 'n1', 'uid-collab'));

      expect(await pieceUpdatedMillis()).toBeGreaterThan(before);
      expect((await watermark('uid-collab'))?.uid).toBe('uid-collab');
    },
  );

  it('ignores a note with no authorId', { timeout: TIMEOUT }, async () => {
    await seedPiece();
    const before = await pieceUpdatedMillis();

    await onNoteWrite.run(noteEvent('p1', 'n1'));

    expect(await pieceUpdatedMillis()).toBe(before);
  });
});
