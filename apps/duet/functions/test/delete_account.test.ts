import type { CallableRequest } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import { deleteAccount } from '../src/deleteAccount';
import { adminAuth, db } from '../src/firebase';

// Under `npm test` these are exported by `firebase emulators:exec`; the
// fallbacks serve `npm run test:against-running` (e.g. over ../dev.sh).
// Safe despite import hoisting: ../src/firebase initializes lazily.
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
process.env.GCLOUD_PROJECT ??= 'demo-duet';

const PROJECT = process.env.GCLOUD_PROJECT;
// Emulator round-trips; the vitest default (5s) is too twitchy under load.
const TIMEOUT = 20_000;

type AuthData = NonNullable<CallableRequest['auth']>;

/** A callable request from [uid], who signed in [authAgeSeconds] ago. */
const requestFor = (uid: string, authAgeSeconds = 0): CallableRequest =>
  ({
    data: {},
    acceptsStreaming: false,
    auth: {
      uid,
      token: { auth_time: Date.now() / 1000 - authAgeSeconds },
    } as AuthData,
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
 * Seeds one account end to end: an Auth user, a `usersByEmail` doc per
 * email (first one is "current"), a device-token doc, and inbox messages.
 */
async function seedUser(uid: string, emails: string[], messages: number) {
  await adminAuth().createUser({ uid, email: emails[0] });
  for (const email of emails) {
    await db().doc(`usersByEmail/${email}`).set({
      uid,
      email,
      displayName: uid,
      discoverable: true,
    });
  }
  await db()
    .doc(`deviceTokens/${uid}`)
    .set({ tokens: [`token-${uid}`] });
  for (let i = 0; i < messages; i++) {
    await db().doc(`userInbox/${uid}/messages/m${i}`).set({
      toUid: uid,
      fromUid: 'uid-someone',
      type: 'invite',
      read: false,
    });
  }
}

/** Everything [seedUser] created for [uid], counted back out. */
async function remainsOf(uid: string) {
  const directory = await db()
    .collection('usersByEmail')
    .where('uid', '==', uid)
    .get();
  const tokenDoc = await db().doc(`deviceTokens/${uid}`).get();
  const inbox = await db().collection(`userInbox/${uid}/messages`).get();
  const authUser = await adminAuth()
    .getUser(uid)
    .then(() => true)
    .catch(() => false);
  return {
    directoryEntries: directory.size,
    hasTokenDoc: tokenDoc.exists,
    inboxMessages: inbox.size,
    hasAuthUser: authUser,
  };
}

describe('deleteAccount', () => {
  beforeEach(clearEmulators, TIMEOUT);

  it('rejects an unauthenticated call', { timeout: TIMEOUT }, async () => {
    await expect(deleteAccount.run(unauthenticated())).rejects.toMatchObject({
      code: 'unauthenticated',
    });
  });

  it(
    'rejects a stale sign-in before touching any data',
    { timeout: TIMEOUT },
    async () => {
      await seedUser('uid-sam', ['sam@example.com'], 1);
      await expect(
        deleteAccount.run(requestFor('uid-sam', /* tenMinutesAgo */ 600)),
      ).rejects.toMatchObject({ code: 'failed-precondition' });
      expect(await remainsOf('uid-sam')).toEqual({
        directoryEntries: 1,
        hasTokenDoc: true,
        inboxMessages: 1,
        hasAuthUser: true,
      });
    },
  );

  it(
    'purges everything the caller owns — and nothing of anyone else',
    { timeout: TIMEOUT },
    async () => {
      // Sam has two directory entries: the doc id is an email key, so an
      // address change leaves an old entry only a field query finds.
      await seedUser('uid-sam', ['sam@example.com', 'old@example.com'], 3);
      await seedUser('uid-mallory', ['mallory@example.com'], 1);

      const result = await deleteAccount.run(requestFor('uid-sam'));

      expect(result).toEqual({
        status: 'deleted',
        directoryEntries: 2,
        deviceTokens: 1,
        inboxMessages: 3,
        ownedPieces: 0,
        leftPieces: 0,
      });
      expect(await remainsOf('uid-sam')).toEqual({
        directoryEntries: 0,
        hasTokenDoc: false,
        inboxMessages: 0,
        hasAuthUser: false,
      });
      expect(await remainsOf('uid-mallory')).toEqual({
        directoryEntries: 1,
        hasTokenDoc: true,
        inboxMessages: 1,
        hasAuthUser: true,
      });
    },
  );

  it(
    'is idempotent: a repeat call after a full purge succeeds with zeros',
    { timeout: TIMEOUT },
    async () => {
      await seedUser('uid-sam', ['sam@example.com'], 1);
      await deleteAccount.run(requestFor('uid-sam'));

      const rerun = await deleteAccount.run(requestFor('uid-sam'));

      expect(rerun).toEqual({
        status: 'deleted',
        directoryEntries: 0,
        deviceTokens: 0,
        inboxMessages: 0,
        ownedPieces: 0,
        leftPieces: 0,
      });
    },
  );

  it(
    'M3.8: deletes owned pieces and removes the caller from shared ones',
    { timeout: TIMEOUT },
    async () => {
      await seedUser('uid-sam', ['sam@example.com'], 0);
      // An owned piece — deleted whole (onPieceDeleted cascades the subtree,
      // which the functions emulator doesn't auto-fire here; we assert the doc).
      await db().doc('pieces/owned-1').set({
        ownerId: 'uid-sam',
        title: 'Mine',
        participantIds: ['uid-sam'],
        collaborators: [],
      });
      // A piece Sam only collaborates on, with a layer + note she authored.
      await db().doc('pieces/shared-1').set({
        ownerId: 'uid-owner',
        title: 'Theirs',
        participantIds: ['uid-owner', 'uid-sam'],
        collaborators: [{ uid: 'uid-sam', name: 'Sam', email: 's@x.z' }],
      });
      await db()
        .doc('pieces/shared-1/layers/uid-sam')
        .set({ ownerId: 'uid-sam', strokes: [] });
      await db()
        .doc('pieces/shared-1/notes/n1')
        .set({ authorId: 'uid-sam', audioAssetId: 'a1' });
      // The owner's own note must be left untouched.
      await db()
        .doc('pieces/shared-1/notes/n2')
        .set({ authorId: 'uid-owner', audioAssetId: 'a2' });

      const result = await deleteAccount.run(requestFor('uid-sam'));

      expect(result).toMatchObject({ ownedPieces: 1, leftPieces: 1 });
      expect((await db().doc('pieces/owned-1').get()).exists).toBe(false);
      // Sam is dropped from the shared piece's participant arrays...
      const shared = (await db().doc('pieces/shared-1').get()).data();
      expect(shared?.participantIds).toEqual(['uid-owner']);
      expect(shared?.collaborators).toEqual([]);
      // ...her authored slice is deleted, the owner's note is not.
      expect(
        (await db().doc('pieces/shared-1/layers/uid-sam').get()).exists,
      ).toBe(false);
      expect((await db().doc('pieces/shared-1/notes/n1').get()).exists).toBe(
        false,
      );
      expect((await db().doc('pieces/shared-1/notes/n2').get()).exists).toBe(
        true,
      );
    },
  );
});
