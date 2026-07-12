import type { CallableRequest } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import { db } from '../src/firebase';
import { lookupEmail } from '../src/lookupEmail';

// Emulator-backed (Firestore only). See invite_lifecycle.test.ts for the same
// host/clear plumbing.
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.GCLOUD_PROJECT ??= 'demo-duet';
const PROJECT = process.env.GCLOUD_PROJECT;
const TIMEOUT = 20_000;

type AuthData = NonNullable<CallableRequest['auth']>;

const requestFrom = (uid: string, data: unknown): CallableRequest =>
  ({ data, acceptsStreaming: false, auth: { uid, token: {} } as AuthData }) as
    CallableRequest;

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

async function seedDirectory(email: string, uid: string, discoverable = true) {
  await db().doc(`usersByEmail/${email}`).set({
    uid,
    email,
    displayName: uid,
    discoverable,
  });
}

describe('lookupEmail', () => {
  beforeEach(clearFirestore, TIMEOUT);

  it('rejects an unauthenticated caller', { timeout: TIMEOUT }, async () => {
    await expect(
      lookupEmail.run(unauthenticated({ email: 'x@y.z' })),
    ).rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it('resolves a discoverable entry (case-insensitive)', { timeout: TIMEOUT }, async () => {
    await seedDirectory('sam@example.com', 'uid-sam');

    const result = await lookupEmail.run(
      requestFrom('uid-caller', { email: 'Sam@Example.com' }),
    );

    expect(result).toEqual({
      user: {
        uid: 'uid-sam',
        email: 'sam@example.com',
        displayName: 'uid-sam',
        discoverable: true,
      },
    });
  });

  it(
    'returns null for an absent or non-discoverable email (indistinguishable)',
    { timeout: TIMEOUT },
    async () => {
      await seedDirectory('hidden@example.com', 'uid-hidden', false);

      const hidden = await lookupEmail.run(
        requestFrom('uid-caller', { email: 'hidden@example.com' }),
      );
      const absent = await lookupEmail.run(
        requestFrom('uid-caller', { email: 'nobody@example.com' }),
      );

      expect(hidden).toEqual({ user: null });
      expect(absent).toEqual({ user: null });
    },
  );

  it(
    'trips a resource-exhausted error past the per-caller window limit',
    { timeout: TIMEOUT },
    async () => {
      await seedDirectory('sam@example.com', 'uid-sam');
      // 20 lookups in the window are allowed; the 21st trips.
      for (let i = 0; i < 20; i++) {
        await lookupEmail.run(
          requestFrom('uid-spammer', { email: 'sam@example.com' }),
        );
      }
      await expect(
        lookupEmail.run(requestFrom('uid-spammer', { email: 'sam@example.com' })),
      ).rejects.toMatchObject({ code: 'resource-exhausted' });

      // A different caller is unaffected (the window is per-uid).
      await expect(
        lookupEmail.run(requestFrom('uid-other', { email: 'sam@example.com' })),
      ).resolves.toMatchObject({ user: { uid: 'uid-sam' } });
    },
  );

  it(
    'resets the window once it has elapsed',
    { timeout: TIMEOUT },
    async () => {
      await seedDirectory('sam@example.com', 'uid-sam');
      // Pre-age the caller's window past WINDOW_MS with the counter maxed.
      await db().doc('rateLimits/uid-aged').set({
        windowStart: new Date(Date.now() - 61_000),
        count: 20,
      });

      // The stale window resets, so this call succeeds rather than tripping.
      await expect(
        lookupEmail.run(requestFrom('uid-aged', { email: 'sam@example.com' })),
      ).resolves.toMatchObject({ user: { uid: 'uid-sam' } });
    },
  );
});
