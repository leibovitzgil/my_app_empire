import type { CallableRequest } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import { db } from '../src/firebase';
import { sendNudge } from '../src/sendNudge';

// Emulator-backed (Firestore only — this callable never touches Auth). Under
// `npm test` the host is exported by `firebase emulators:exec`.
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.GCLOUD_PROJECT ??= 'demo-duet';
const PROJECT = process.env.GCLOUD_PROJECT;
const TIMEOUT = 20_000;

type AuthData = NonNullable<CallableRequest['auth']>;

/** A callable request from [uid] (optionally carrying a token display name). */
function requestFrom(
  uid: string,
  data: unknown,
  name?: string,
): CallableRequest {
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

/** Creates a `pieces/{pieceId}` doc with the given participants. */
async function seedPiece(
  pieceId: string,
  ownerId: string,
  collaboratorIds: string[] = [],
) {
  await db().doc(`pieces/${pieceId}`).set({
    ownerId,
    title: pieceId,
    participantIds: [ownerId, ...collaboratorIds],
  });
}

async function inboxOf(uid: string) {
  return (await db().collection(`userInbox/${uid}/messages`).get()).docs.map(
    (d) => d.data(),
  );
}

describe('sendNudge', () => {
  beforeEach(clearFirestore, TIMEOUT);

  it('rejects an unauthenticated caller', { timeout: TIMEOUT }, async () => {
    await expect(
      sendNudge.run(unauthenticated({ pieceId: 'p1' })),
    ).rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it('rejects a missing pieceId', { timeout: TIMEOUT }, async () => {
    await expect(
      sendNudge.run(requestFrom('uid-owner', {})),
    ).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('rejects a nudge on a missing piece', { timeout: TIMEOUT }, async () => {
    await expect(
      sendNudge.run(requestFrom('uid-owner', { pieceId: 'nope' })),
    ).rejects.toMatchObject({ code: 'not-found' });
  });

  it(
    'rejects a caller who is not a participant',
    { timeout: TIMEOUT },
    async () => {
      await seedPiece('p1', 'uid-owner', ['uid-collab']);
      await expect(
        sendNudge.run(requestFrom('uid-stranger', { pieceId: 'p1' })),
      ).rejects.toMatchObject({ code: 'permission-denied' });
    },
  );

  it(
    'fans a nudge out to every other participant, never the sender',
    { timeout: TIMEOUT },
    async () => {
      await seedPiece('p1', 'uid-owner', ['uid-collab', 'uid-collab2']);

      const result = await sendNudge.run(
        requestFrom('uid-owner', { pieceId: 'p1' }, 'Ada'),
      );
      expect(result).toMatchObject({ status: 'sent', recipientCount: 2 });

      const collabInbox = await inboxOf('uid-collab');
      expect(collabInbox).toHaveLength(1);
      expect(collabInbox[0]).toMatchObject({
        toUid: 'uid-collab',
        title: 'Ada added notes',
        data: { type: 'nudge', pieceId: 'p1', fromName: 'Ada' },
        read: false,
      });
      expect(await inboxOf('uid-collab2')).toHaveLength(1);
      // The sender never nudges themselves.
      expect(await inboxOf('uid-owner')).toHaveLength(0);
    },
  );

  it(
    'falls back to "Someone" when the caller has no token name',
    { timeout: TIMEOUT },
    async () => {
      await seedPiece('p1', 'uid-owner', ['uid-collab']);
      await sendNudge.run(requestFrom('uid-owner', { pieceId: 'p1' }));
      const inbox = await inboxOf('uid-collab');
      expect(inbox[0]).toMatchObject({ title: 'Someone added notes' });
    },
  );
});
