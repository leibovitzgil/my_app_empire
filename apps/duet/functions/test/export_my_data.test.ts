import type { CallableRequest } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import { adminAuth, db } from '../src/firebase';
import { exportMyData, gatherExport } from '../src/exportMyData';

// Under `npm test` these are exported by `firebase emulators:exec`; the
// fallbacks serve `npm run test:against-running`. Safe despite import
// hoisting: ../src/firebase initializes lazily.
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
process.env.GCLOUD_PROJECT ??= 'demo-duet';

const PROJECT = process.env.GCLOUD_PROJECT;
// Emulator round-trips; the vitest default (5s) is too twitchy under load.
const TIMEOUT = 20_000;

type AuthData = NonNullable<CallableRequest['auth']>;

const requestFor = (uid: string): CallableRequest =>
  ({
    data: {},
    acceptsStreaming: false,
    auth: { uid, token: {} } as AuthData,
  }) as CallableRequest;

const unauthenticated = (): CallableRequest =>
  ({ data: {}, acceptsStreaming: false }) as CallableRequest;

/** Wipes both emulators so each test starts from nothing. */
async function clearEmulators() {
  const firestore = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/` +
      `${PROJECT}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  const auth = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/` +
      `projects/${PROJECT}/accounts`,
    { method: 'DELETE' },
  );
  if (!firestore.ok || !auth.ok) {
    throw new Error(
      `emulator clear failed: firestore=${firestore.status} ` +
        `auth=${auth.status}`,
    );
  }
}

/**
 * Seeds an Auth user + a `usersByEmail` directory entry, a device-token doc,
 * an inbox message, and an entitlement doc. Returns the uid for chaining.
 */
async function seedUser(uid: string, email: string, pro = false) {
  await adminAuth().createUser({ uid, email, displayName: uid });
  await db().doc(`usersByEmail/${email}`).set({
    uid,
    email,
    displayName: uid,
    discoverable: true,
  });
  await db()
    .doc(`deviceTokens/${uid}`)
    .set({ tokens: [`token-${uid}`] });
  await db()
    .doc(`userInbox/${uid}/messages/m1`)
    .set({ toUid: uid, fromUid: 'someone', type: 'invite', read: false });
  await db().doc(`entitlements/${uid}`).set({ pro });
  return uid;
}

/**
 * A piece [owner] owns; every uid in [participants] gets a layer + one note
 * they authored (so a shared piece carries two collaborators' slices).
 */
async function seedPiece(
  pieceId: string,
  owner: string,
  participants: string[],
) {
  await db()
    .doc(`pieces/${pieceId}`)
    .set({
      title: `Piece ${pieceId}`,
      ownerId: owner,
      ownerName: owner,
      participantIds: participants,
      collaborators: participants.map((uid) => ({ uid, name: uid })),
      basePdfChecksum: `sum-${pieceId}`,
    });
  for (const uid of participants) {
    await db()
      .doc(`pieces/${pieceId}/layers/${uid}`)
      .set({ ownerId: uid, role: uid === owner ? 'owner' : 'collaborator' });
    await db()
      .doc(`pieces/${pieceId}/notes/note-${uid}`)
      .set({ authorId: uid, audioAssetId: `audio-${uid}`, pageIndex: 0 });
  }
}

describe('exportMyData', () => {
  beforeEach(clearEmulators, TIMEOUT);

  it('rejects an unauthenticated call', { timeout: TIMEOUT }, async () => {
    await expect(exportMyData.run(unauthenticated())).rejects.toMatchObject({
      code: 'unauthenticated',
    });
  });

  it(
    'exports exactly-and-only the caller: A gets A, never B',
    { timeout: TIMEOUT },
    async () => {
      const a = await seedUser('uid-a', 'a@example.com', /* pro */ true);
      const b = await seedUser('uid-b', 'b@example.com');
      // A shared piece (both author a slice) and one piece each owns alone.
      await seedPiece('shared', a, [a, b]);
      await seedPiece('a-solo', a, [a]);
      await seedPiece('b-solo', b, [b]);

      const bundle = await gatherExport(a);

      // Profile + directory + entitlement are A's.
      expect(bundle.uid).toBe(a);
      expect(bundle.profile.email).toBe('a@example.com');
      expect(bundle.directory.map((d) => d.emailKey)).toEqual([
        'a@example.com',
      ]);
      expect(bundle.entitlement).toEqual({ pro: true });
      expect(bundle.deviceTokens).toEqual(['token-uid-a']);
      expect(bundle.inbox).toHaveLength(1);

      // Pieces: the shared one + A's solo, never B's solo.
      const pieceIds = bundle.pieces.map((p) => p.pieceId).sort();
      expect(pieceIds).toEqual(['a-solo', 'shared']);

      const shared = bundle.pieces.find((p) => p.pieceId === 'shared');
      expect(shared?.role).toBe('owner');
      // Only A's layer + note ride along — none of B's slice on the shared
      // piece leaks into A's export.
      expect(shared?.layer?.ownerId).toBe(a);
      expect(shared?.notes.map((n) => n.authorId)).toEqual([a]);
      expect(shared?.audioAssets.map((x) => x.assetId)).toEqual([
        'audio-uid-a',
      ]);
      // B's co-membership on the shared piece is legitimately part of A's
      // metadata (A's own piece lists its participants), so `uid-b` appears
      // there — but none of B's *private* data may leak: not B's directory
      // entry, notes, audio, layer, tokens, inbox, or solo piece.
      const asJson = JSON.stringify(bundle);
      expect(asJson).not.toContain('b@example.com');
      expect(asJson).not.toContain('note-uid-b');
      expect(asJson).not.toContain('audio-uid-b');
      expect(asJson).not.toContain('token-uid-b');
      expect(asJson).not.toContain('b-solo');
    },
  );

  it(
    'signs no audio URLs when no bucket is available (emulator)',
    { timeout: TIMEOUT },
    async () => {
      const a = await seedUser('uid-a', 'a@example.com');
      await seedPiece('p1', a, [a]);

      const bundle = await gatherExport(a);

      const asset = bundle.pieces[0]?.audioAssets[0];
      expect(asset?.path).toBe('pieces/p1/audio/audio-uid-a');
      expect(asset?.downloadUrl).toBeNull();
    },
  );

  it(
    'the callable returns honest counts (null URL without a bucket)',
    { timeout: TIMEOUT },
    async () => {
      const a = await seedUser('uid-a', 'a@example.com');
      await seedPiece('shared', a, [a, 'uid-b']);
      await seedPiece('a-solo', a, [a]);

      const result = await exportMyData.run(requestFor(a));

      expect(result.status).toBe('exported');
      expect(result.downloadUrl).toBeNull();
      expect(result.counts).toEqual({
        pieces: 2,
        notes: 2, // one on each of A's pieces; B's note on `shared` excluded
        audioAssets: 2,
        directoryEntries: 1,
      });
    },
  );

  it(
    'rate-limits to once per day per uid',
    { timeout: TIMEOUT },
    async () => {
      const a = await seedUser('uid-a', 'a@example.com');

      await exportMyData.run(requestFor(a));
      await expect(exportMyData.run(requestFor(a))).rejects.toMatchObject({
        code: 'resource-exhausted',
      });

      // A different uid is unaffected — the limiter is per-uid.
      await seedUser('uid-c', 'c@example.com');
      const other = await exportMyData.run(requestFor('uid-c'));
      expect(other.status).toBe('exported');
    },
  );
});
