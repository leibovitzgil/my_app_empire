import type { CallableRequest } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import { acceptInvite } from '../src/acceptInvite';
import { db } from '../src/firebase';
import { leavePiece } from '../src/leavePiece';
import { sendInvite } from '../src/sendInvite';

// Emulator-backed (Firestore only — these callables never touch Auth). Under
// `npm test` the host is exported by `firebase emulators:exec`; the fallback
// serves `npm run test:against-running`.
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.GCLOUD_PROJECT ??= 'demo-duet';
const PROJECT = process.env.GCLOUD_PROJECT;
const TIMEOUT = 20_000;

type AuthData = NonNullable<CallableRequest['auth']>;

/** A callable request from [uid] (optionally carrying a token display name). */
function requestFrom(uid: string, data: unknown, name?: string): CallableRequest {
  return {
    data,
    acceptsStreaming: false,
    auth: { uid, token: name == null ? {} : { name } } as AuthData,
  } as CallableRequest;
}

const unauthenticated = (data: unknown): CallableRequest =>
  ({ data, acceptsStreaming: false }) as CallableRequest;

async function clearFirestore() {
  const res = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/` +
      `${PROJECT}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  if (!res.ok) throw new Error(`clear failed: ${res.status}`);
}

/** Publishes a `usersByEmail` directory entry (the invite resolves against). */
async function seedDirectory(
  email: string,
  uid: string,
  discoverable = true,
) {
  await db().doc(`usersByEmail/${email}`).set({
    uid,
    email,
    displayName: uid,
    discoverable,
  });
}

/** Creates a `pieces/{pieceId}` doc owned by [ownerId] (sendInvite's gate). */
async function seedPiece(pieceId: string, ownerId: string) {
  await db().doc(`pieces/${pieceId}`).set({
    ownerId,
    title: pieceId,
    participantIds: [ownerId],
  });
}

async function inboxOf(uid: string) {
  return (await db().collection(`userInbox/${uid}/messages`).get()).docs.map(
    (d) => d.data(),
  );
}

describe('sendInvite', () => {
  beforeEach(clearFirestore, TIMEOUT);

  it('rejects an unauthenticated caller', { timeout: TIMEOUT }, async () => {
    await expect(
      sendInvite.run(unauthenticated({ pieceId: 'p1', inviteeEmail: 'x@y.z' })),
    ).rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it('rejects a missing pieceId / email', { timeout: TIMEOUT }, async () => {
    await expect(
      sendInvite.run(requestFrom('uid-owner', { inviteeEmail: 'x@y.z' })),
    ).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it(
    'resolves a discoverable invitee and writes their inbox',
    { timeout: TIMEOUT },
    async () => {
      await seedPiece('p1', 'uid-owner');
      await seedDirectory('sam@example.com', 'uid-sam');

      const result = await sendInvite.run(
        requestFrom(
          'uid-owner',
          { pieceId: 'p1', inviteeEmail: 'Sam@Example.com' },
          'Olivia',
        ),
      );

      expect(result).toMatchObject({ status: 'sent', recipientUid: 'uid-sam' });
      const inbox = await inboxOf('uid-sam');
      expect(inbox).toHaveLength(1);
      expect(inbox[0]).toMatchObject({
        toUid: 'uid-sam',
        title: 'Olivia invited you to collaborate',
        read: false,
        data: { type: 'invite', pieceId: 'p1', ownerId: 'uid-owner' },
      });
    },
  );

  it(
    'a non-discoverable or absent email yields no-account and writes nothing',
    { timeout: TIMEOUT },
    async () => {
      await seedPiece('p1', 'uid-owner');
      await seedDirectory('hidden@example.com', 'uid-hidden', false);

      const hidden = await sendInvite.run(
        requestFrom('uid-owner', {
          pieceId: 'p1',
          inviteeEmail: 'hidden@example.com',
        }),
      );
      const absent = await sendInvite.run(
        requestFrom('uid-owner', {
          pieceId: 'p1',
          inviteeEmail: 'nobody@example.com',
        }),
      );

      expect(hidden).toEqual({ status: 'no-account' });
      expect(absent).toEqual({ status: 'no-account' });
      expect(await inboxOf('uid-hidden')).toHaveLength(0);
    },
  );

  it(
    'rejects inviting to a piece the caller does not own',
    { timeout: TIMEOUT },
    async () => {
      await seedPiece('p1', 'uid-someone-else');
      await seedDirectory('sam@example.com', 'uid-sam');

      await expect(
        sendInvite.run(
          requestFrom('uid-owner', {
            pieceId: 'p1',
            inviteeEmail: 'sam@example.com',
          }),
        ),
      ).rejects.toMatchObject({ code: 'permission-denied' });
      expect(await inboxOf('uid-sam')).toHaveLength(0);
    },
  );

  it(
    'rejects inviting to a piece that does not exist',
    { timeout: TIMEOUT },
    async () => {
      await expect(
        sendInvite.run(
          requestFrom('uid-owner', {
            pieceId: 'ghost',
            inviteeEmail: 'sam@example.com',
          }),
        ),
      ).rejects.toMatchObject({ code: 'not-found' });
    },
  );
});

describe('acceptInvite', () => {
  beforeEach(clearFirestore, TIMEOUT);

  async function seedInvite(toUid: string, messageId: string, read = false) {
    await db().doc(`userInbox/${toUid}/messages/${messageId}`).set({
      toUid,
      title: 'Invite',
      body: 'Join',
      data: { type: 'invite', pieceId: 'p1', ownerId: 'uid-owner' },
      sentAtMillis: 1,
      read,
    });
  }

  it('marks an addressed, unread invite read', { timeout: TIMEOUT }, async () => {
    await seedInvite('uid-sam', 'm1');

    const result = await acceptInvite.run(
      requestFrom('uid-sam', { messageId: 'm1' }),
    );

    expect(result).toMatchObject({ status: 'accepted', pieceId: 'p1' });
    const msg = (
      await db().doc('userInbox/uid-sam/messages/m1').get()
    ).data();
    expect(msg?.read).toBe(true);
  });

  it('rejects accepting someone else’s message', { timeout: TIMEOUT }, async () => {
    await seedInvite('uid-sam', 'm1');
    // uid-mallory has no such message in her own inbox.
    await expect(
      acceptInvite.run(requestFrom('uid-mallory', { messageId: 'm1' })),
    ).rejects.toMatchObject({ code: 'not-found' });
  });

  it('rejects an already-consumed invite', { timeout: TIMEOUT }, async () => {
    await seedInvite('uid-sam', 'm1', /* read */ true);
    await expect(
      acceptInvite.run(requestFrom('uid-sam', { messageId: 'm1' })),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});

describe('leavePiece', () => {
  beforeEach(clearFirestore, TIMEOUT);

  it(
    'is a no-op success when no piece document exists yet (pre-M3)',
    { timeout: TIMEOUT },
    async () => {
      const result = await leavePiece.run(
        requestFrom('uid-collab', { pieceId: 'p1' }),
      );
      expect(result).toEqual({ status: 'left', removed: false });
    },
  );

  it('rejects unauthenticated', { timeout: TIMEOUT }, async () => {
    await expect(
      leavePiece.run(unauthenticated({ pieceId: 'p1' })),
    ).rejects.toMatchObject({ code: 'unauthenticated' });
  });
});
