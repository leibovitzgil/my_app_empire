import type { BatchResponse } from 'firebase-admin/messaging';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { db } from '../src/firebase';
import { onInboxMessageCreated } from '../src/inboxPush';

// Emulator-backed Firestore, mocked FCM: there is no FCM emulator, so
// `firebase-admin/messaging` is replaced at the module level and only the
// Firestore side (token reads, pruning, the `pushed` mark) runs for real.
// Under `npm test` the host is exported by `firebase emulators:exec`; the
// fallback serves `npm run test:against-running`.
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.GCLOUD_PROJECT ??= 'demo-duet';
const TIMEOUT = 20_000;

const sendEachForMulticast = vi.fn<() => Promise<BatchResponse>>();

vi.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({ sendEachForMulticast }),
}));

// No `clearFirestore` here, deliberately — unique ids per test instead, so
// the suite is safe under `test:against-running` next to a live emulator
// session (see invite_tokens.test.ts for the full rationale).
let seq = 0;
const uniq = (prefix: string) => `${prefix}-${Date.now()}-${seq++}`;

/** A successful per-token send result. */
const ok = () => ({ success: true as const });

/** A failed per-token send result carrying [code]. */
const failed = (code: string) => ({
  success: false as const,
  error: { code },
});

const batchResponse = (
  responses: Array<{ success: boolean; error?: { code: string } }>,
): BatchResponse =>
  ({
    responses,
    successCount: responses.filter((r) => r.success).length,
    failureCount: responses.filter((r) => !r.success).length,
  }) as unknown as BatchResponse;

/**
 * Seeds an inbox message doc (the shape `sendInvite`/`sendNudge` write),
 * then builds the created-event the trigger would receive for it. The
 * `--only auth,firestore` suite runs no functions emulator, so the trigger
 * is invoked directly with `.run(event)` (the piece_cascade pattern).
 */
async function seedMessage(
  uid: string,
  messageId: string,
  data: Record<string, string>,
) {
  const ref = db().doc(`userInbox/${uid}/messages/${messageId}`);
  await ref.set({
    toUid: uid,
    title: 'Jane invited you to collaborate',
    body: 'Join a shared piece on Duet.',
    data,
    sentAtMillis: Date.now(),
    read: false,
    requiresAction: true,
  });
  const snap = await ref.get();
  return { params: { uid, messageId }, data: snap } as unknown as Parameters<
    typeof onInboxMessageCreated.run
  >[0];
}

describe('onInboxMessageCreated', () => {
  beforeEach(() => {
    sendEachForMulticast.mockReset();
  });

  it(
    'multicasts to the registered tokens and marks the message pushed',
    { timeout: TIMEOUT },
    async () => {
      const uid = uniq('uid');
      const messageId = uniq('m');
      const pieceId = uniq('p');
      await db()
        .doc(`deviceTokens/${uid}`)
        .set({ tokens: ['token-a', 'token-b'] });
      sendEachForMulticast.mockResolvedValue(batchResponse([ok(), ok()]));

      const event = await seedMessage(uid, messageId, {
        type: 'invite',
        pieceId,
      });
      await onInboxMessageCreated.run(event);

      expect(sendEachForMulticast).toHaveBeenCalledExactlyOnceWith({
        tokens: ['token-a', 'token-b'],
        notification: {
          title: 'Jane invited you to collaborate',
          body: 'Join a shared piece on Duet.',
        },
        data: {
          type: 'invite',
          pieceId,
          deepLink: `https://duet.app/piece/${pieceId}`,
        },
      });
      const message = await db()
        .doc(`userInbox/${uid}/messages/${messageId}`)
        .get();
      // The client bridge skips `pushed` messages — this mark is the
      // foreground-dedupe contract.
      expect(message.data()?.pushed).toBe(true);
      // Marking pushed must not clobber the rest of the doc (merge write).
      expect(message.data()?.read).toBe(false);
      expect(message.data()?.requiresAction).toBe(true);
    },
  );

  it(
    'sends nothing when the recipient has no deviceTokens doc',
    { timeout: TIMEOUT },
    async () => {
      const uid = uniq('uid');
      const messageId = uniq('m');

      const event = await seedMessage(uid, messageId, { type: 'nudge' });
      await onInboxMessageCreated.run(event);

      expect(sendEachForMulticast).not.toHaveBeenCalled();
      // No push delivered -> `pushed` stays unset so the foreground bridge
      // remains the delivery path.
      const message = await db()
        .doc(`userInbox/${uid}/messages/${messageId}`)
        .get();
      expect(message.data()?.pushed).toBeUndefined();
    },
  );

  it(
    'sends nothing when the tokens array is empty',
    { timeout: TIMEOUT },
    async () => {
      const uid = uniq('uid');
      const messageId = uniq('m');
      await db().doc(`deviceTokens/${uid}`).set({ tokens: [] });

      const event = await seedMessage(uid, messageId, { type: 'nudge' });
      await onInboxMessageCreated.run(event);

      expect(sendEachForMulticast).not.toHaveBeenCalled();
    },
  );

  it(
    'prunes an unregistered token but keeps the live ones',
    { timeout: TIMEOUT },
    async () => {
      const uid = uniq('uid');
      const messageId = uniq('m');
      await db()
        .doc(`deviceTokens/${uid}`)
        .set({ tokens: ['dead-token', 'live-token'] });
      sendEachForMulticast.mockResolvedValue(
        batchResponse([
          failed('messaging/registration-token-not-registered'),
          ok(),
        ]),
      );

      const event = await seedMessage(uid, messageId, { type: 'nudge' });
      await onInboxMessageCreated.run(event);

      const tokens = await db().doc(`deviceTokens/${uid}`).get();
      expect(tokens.data()?.tokens).toEqual(['live-token']);
      // One device still got the push, so the bridge is still suppressed.
      const message = await db()
        .doc(`userInbox/${uid}/messages/${messageId}`)
        .get();
      expect(message.data()?.pushed).toBe(true);
    },
  );

  it(
    'keeps tokens on transient failures and leaves the message unpushed ' +
      'when every send fails',
    { timeout: TIMEOUT },
    async () => {
      const uid = uniq('uid');
      const messageId = uniq('m');
      await db().doc(`deviceTokens/${uid}`).set({ tokens: ['flaky-token'] });
      sendEachForMulticast.mockResolvedValue(
        batchResponse([failed('messaging/internal-error')]),
      );

      const event = await seedMessage(uid, messageId, { type: 'nudge' });
      await onInboxMessageCreated.run(event);

      // A transient failure is not an unregistered device: keep the token.
      const tokens = await db().doc(`deviceTokens/${uid}`).get();
      expect(tokens.data()?.tokens).toEqual(['flaky-token']);
      // Nothing was delivered, so the bridge must still surface it.
      const message = await db()
        .doc(`userInbox/${uid}/messages/${messageId}`)
        .get();
      expect(message.data()?.pushed).toBeUndefined();
    },
  );
});
