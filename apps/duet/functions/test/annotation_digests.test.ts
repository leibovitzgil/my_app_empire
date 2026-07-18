import { Timestamp } from 'firebase-admin/firestore';
import type { BatchResponse, MulticastMessage } from 'firebase-admin/messaging';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import type { DigestDoc } from '../src/annotationDigests';
import {
  composeDigestCopy,
  drainPushDigestsOnce,
  groupDigests,
  onLayerAnnotationsChanged,
  onNoteAnnotationsChanged,
} from '../src/annotationDigests';
import { db } from '../src/firebase';

// Emulator-backed Firestore, mocked FCM (there is no FCM emulator) — the
// inbox_push.test.ts pattern. Under `npm test` the host is exported by
// `firebase emulators:exec`; the fallback serves `test:against-running`.
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.GCLOUD_PROJECT ??= 'demo-duet';
const TIMEOUT = 20_000;

const sendEachForMulticast = vi.fn<
  (message: MulticastMessage) => Promise<BatchResponse>
>();

vi.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({ sendEachForMulticast }),
}));

// No `clearFirestore`, deliberately — unique ids per test, so the suite is
// safe under `test:against-running` next to a live emulator session. The
// drain scans the WHOLE `pushDigests` collection, so drain assertions filter
// the mock's calls by this test's own (unique) tokens rather than asserting
// global call counts.
let seq = 0;
const uniq = (prefix: string) => `${prefix}-${Date.now()}-${seq++}`;

/** Every token in [message] succeeds — echo a matching batch response. */
const allOk = (message: MulticastMessage): Promise<BatchResponse> =>
  Promise.resolve({
    responses: message.tokens.map(() => ({ success: true })),
    successCount: message.tokens.length,
    failureCount: 0,
  } as unknown as BatchResponse);

/** The multicast calls that targeted [token] (drain-test isolation). */
const callsFor = (token: string): MulticastMessage[] =>
  sendEachForMulticast.mock.calls
    .map(([message]) => message)
    .filter((message) => message.tokens.includes(token));

const ts = (millis: number) => Timestamp.fromMillis(millis);

const digest = (partial: Partial<DigestDoc>): DigestDoc => ({
  pieceId: 'p',
  authorId: 'author',
  recipientIds: ['r1'],
  kind: 'strokes',
  count: 1,
  createdAt: ts(1_000),
  ...partial,
});

async function seedPiece(options: {
  pieceId: string;
  ownerId: string;
  ownerName?: string;
  collaborators?: Array<{ uid: string; name?: string }>;
  title?: string;
}) {
  const collaborators = options.collaborators ?? [];
  await db()
    .doc(`pieces/${options.pieceId}`)
    .set({
      title: options.title ?? 'Clair de Lune',
      ownerId: options.ownerId,
      ...(options.ownerName ? { ownerName: options.ownerName } : {}),
      participantIds: [options.ownerId, ...collaborators.map((c) => c.uid)],
      collaborators,
      updatedAt: Timestamp.now(),
    });
}

const layerEvent = (
  pieceId: string,
  layerId: string,
  afterStrokes: number | null,
  beforeStrokes?: number,
) =>
  ({
    params: { pieceId, layerId },
    data: {
      before: {
        exists: beforeStrokes != null,
        data: () =>
          beforeStrokes == null
            ? undefined
            : { strokes: Array.from({ length: beforeStrokes }, (_, i) => i) },
      },
      after: {
        exists: afterStrokes != null,
        data: () =>
          afterStrokes == null
            ? undefined
            : { strokes: Array.from({ length: afterStrokes }, (_, i) => i) },
      },
    },
  }) as unknown as Parameters<typeof onLayerAnnotationsChanged.run>[0];

const noteEvent = (
  pieceId: string,
  noteId: string,
  after: Record<string, unknown> | null,
  beforeExists = false,
) =>
  ({
    params: { pieceId, noteId },
    data: {
      before: { exists: beforeExists, data: () => undefined },
      after: { exists: after != null, data: () => after ?? undefined },
    },
  }) as unknown as Parameters<typeof onNoteAnnotationsChanged.run>[0];

async function queuedDigestsFor(pieceId: string): Promise<DigestDoc[]> {
  const snapshot = await db()
    .collection('pushDigests')
    .where('pieceId', '==', pieceId)
    .get();
  return snapshot.docs.map((doc) => doc.data() as DigestDoc);
}

describe('composeDigestCopy', () => {
  it('pluralizes: "<author> added <n> notes to <title>"', () => {
    expect(composeDigestCopy('Maya', 3, 'Clair de Lune')).toBe(
      'Maya added 3 notes to Clair de Lune',
    );
  });

  it('uses the singular for one note', () => {
    expect(composeDigestCopy('Maya', 1, 'Clair de Lune')).toBe(
      'Maya added 1 note to Clair de Lune',
    );
  });
});

describe('groupDigests', () => {
  it('sums one (recipient, piece, author) group across kinds', () => {
    const groups = groupDigests([
      digest({ kind: 'strokes', count: 5, createdAt: ts(1_000) }),
      digest({ kind: 'notes', count: 1, createdAt: ts(3_000) }),
      digest({ kind: 'notes', count: 1, createdAt: ts(2_000) }),
    ]);

    expect(groups).toHaveLength(1);
    expect(groups[0].totalCount).toBe(7);
    // The batch time is the NEWEST enqueue — what lastOpenedAt is compared to.
    expect(groups[0].latestCreatedAt.toMillis()).toBe(3_000);
  });

  it('splits distinct authors and recipients into distinct groups', () => {
    const groups = groupDigests([
      digest({ authorId: 'a1', recipientIds: ['r1', 'r2'], count: 2 }),
      digest({ authorId: 'a2', recipientIds: ['r1'], count: 1 }),
    ]);

    expect(groups).toHaveLength(3);
    const keys = groups.map((g) => `${g.recipientId}/${g.authorId}`).sort();
    expect(keys).toEqual(['r1/a1', 'r1/a2', 'r2/a1']);
  });

  it('never groups the author as their own recipient', () => {
    const groups = groupDigests([
      digest({ authorId: 'a1', recipientIds: ['a1', 'r1'] }),
    ]);

    expect(groups).toHaveLength(1);
    expect(groups[0].recipientId).toBe('r1');
  });
});

describe('onLayerAnnotationsChanged', () => {
  it(
    'enqueues the stroke delta addressed to the other participants',
    { timeout: TIMEOUT },
    async () => {
      const pieceId = uniq('p');
      const owner = uniq('owner');
      const collab = uniq('collab');
      await seedPiece({
        pieceId,
        ownerId: owner,
        collaborators: [{ uid: collab, name: 'Maya' }],
      });

      await onLayerAnnotationsChanged.run(layerEvent(pieceId, collab, 5, 2));

      const queued = await queuedDigestsFor(pieceId);
      expect(queued).toHaveLength(1);
      expect(queued[0]).toMatchObject({
        pieceId,
        authorId: collab,
        recipientIds: [owner],
        kind: 'strokes',
        count: 3,
      });
      expect(queued[0].createdAt).toBeInstanceOf(Timestamp);
    },
  );

  it(
    'enqueues nothing for an erase-only rewrite or a removal',
    { timeout: TIMEOUT },
    async () => {
      const pieceId = uniq('p');
      const owner = uniq('owner');
      const collab = uniq('collab');
      await seedPiece({
        pieceId,
        ownerId: owner,
        collaborators: [{ uid: collab }],
      });

      await onLayerAnnotationsChanged.run(layerEvent(pieceId, collab, 1, 2));
      await onLayerAnnotationsChanged.run(layerEvent(pieceId, collab, null, 2));

      expect(await queuedDigestsFor(pieceId)).toHaveLength(0);
    },
  );

  it(
    'enqueues nothing on a solo piece (no one to notify)',
    { timeout: TIMEOUT },
    async () => {
      const pieceId = uniq('p');
      const owner = uniq('owner');
      await seedPiece({ pieceId, ownerId: owner });

      await onLayerAnnotationsChanged.run(layerEvent(pieceId, owner, 3, 0));

      expect(await queuedDigestsFor(pieceId)).toHaveLength(0);
    },
  );
});

describe('onNoteAnnotationsChanged', () => {
  it(
    'enqueues a single note on create, keyed by its authorId',
    { timeout: TIMEOUT },
    async () => {
      const pieceId = uniq('p');
      const owner = uniq('owner');
      const collab = uniq('collab');
      await seedPiece({
        pieceId,
        ownerId: owner,
        ownerName: 'Sam',
        collaborators: [{ uid: collab, name: 'Maya' }],
      });

      await onNoteAnnotationsChanged.run(
        noteEvent(pieceId, uniq('n'), { authorId: owner, deletedAt: null }),
      );

      const queued = await queuedDigestsFor(pieceId);
      expect(queued).toHaveLength(1);
      expect(queued[0]).toMatchObject({
        pieceId,
        authorId: owner,
        recipientIds: [collab],
        kind: 'notes',
        count: 1,
      });
    },
  );

  it(
    'ignores tombstone updates and tombstoned creates',
    { timeout: TIMEOUT },
    async () => {
      const pieceId = uniq('p');
      const owner = uniq('owner');
      const collab = uniq('collab');
      await seedPiece({
        pieceId,
        ownerId: owner,
        collaborators: [{ uid: collab }],
      });

      // The M4.4 tombstone write: before exists, after sets deletedAt.
      await onNoteAnnotationsChanged.run(
        noteEvent(pieceId, uniq('n'), { authorId: owner }, true),
      );
      // A note that arrives already tombstoned is not new content either.
      await onNoteAnnotationsChanged.run(
        noteEvent(pieceId, uniq('n'), {
          authorId: owner,
          deletedAt: Timestamp.now(),
        }),
      );

      expect(await queuedDigestsFor(pieceId)).toHaveLength(0);
    },
  );
});

describe('drainPushDigestsOnce', () => {
  beforeEach(() => {
    sendEachForMulticast.mockReset();
    sendEachForMulticast.mockImplementation(allOk);
  });

  it(
    'a burst of 5 strokes + 2 notes is exactly one digest per recipient',
    { timeout: TIMEOUT },
    async () => {
      const pieceId = uniq('p');
      const author = uniq('maya');
      const owner = uniq('owner');
      const other = uniq('other');
      const ownerToken = uniq('tok');
      const otherToken = uniq('tok');
      await seedPiece({
        pieceId,
        ownerId: owner,
        ownerName: 'Sam',
        collaborators: [
          { uid: author, name: 'Maya' },
          { uid: other, name: 'Ravi' },
        ],
      });
      await db().doc(`deviceTokens/${owner}`).set({ tokens: [ownerToken] });
      await db().doc(`deviceTokens/${other}`).set({ tokens: [otherToken] });

      // The burst, exactly as the triggers would enqueue it: strokes land as
      // deltas (2 + 3), the two audio notes as one doc each.
      await onLayerAnnotationsChanged.run(layerEvent(pieceId, author, 2, 0));
      await onLayerAnnotationsChanged.run(layerEvent(pieceId, author, 5, 2));
      await onNoteAnnotationsChanged.run(
        noteEvent(pieceId, uniq('n'), { authorId: author }),
      );
      await onNoteAnnotationsChanged.run(
        noteEvent(pieceId, uniq('n'), { authorId: author }),
      );

      await drainPushDigestsOnce();

      for (const token of [ownerToken, otherToken]) {
        const calls = callsFor(token);
        expect(calls).toHaveLength(1);
        expect(calls[0].notification?.title).toBe(
          'Maya added 7 notes to Clair de Lune',
        );
        expect(calls[0].data).toEqual({
          type: 'digest',
          pieceId,
          deepLink: `https://duet.app/piece/${pieceId}`,
        });
      }
      // The author's own devices were never targeted, and the queue drained.
      expect(await queuedDigestsFor(pieceId)).toHaveLength(0);
    },
  );

  it(
    'skips a recipient whose pushEnabled mirror is false (muted)',
    { timeout: TIMEOUT },
    async () => {
      const pieceId = uniq('p');
      const author = uniq('maya');
      const owner = uniq('owner');
      const mutedToken = uniq('tok');
      await seedPiece({
        pieceId,
        ownerId: owner,
        collaborators: [{ uid: author, name: 'Maya' }],
      });
      await db()
        .doc(`deviceTokens/${owner}`)
        .set({ tokens: [mutedToken], pushEnabled: false });

      await onLayerAnnotationsChanged.run(layerEvent(pieceId, author, 3, 0));
      await drainPushDigestsOnce();

      expect(callsFor(mutedToken)).toHaveLength(0);
      // Muted is a decision, not a retry: the queue still drained.
      expect(await queuedDigestsFor(pieceId)).toHaveLength(0);
    },
  );

  it(
    'skips a recipient who opened the piece after the batch',
    { timeout: TIMEOUT },
    async () => {
      const pieceId = uniq('p');
      const author = uniq('maya');
      const owner = uniq('owner');
      const token = uniq('tok');
      await seedPiece({
        pieceId,
        ownerId: owner,
        collaborators: [{ uid: author, name: 'Maya' }],
      });
      await db().doc(`deviceTokens/${owner}`).set({ tokens: [token] });

      await onLayerAnnotationsChanged.run(layerEvent(pieceId, author, 3, 0));
      // The recipient opens the sheet AFTER the burst — they saw it.
      await db().doc(`pieces/${pieceId}/reads/${owner}`).set({
        uid: owner,
        lastOpenedAt: Timestamp.fromMillis(Date.now() + 60_000),
      });

      await drainPushDigestsOnce();

      expect(callsFor(token)).toHaveLength(0);
      expect(await queuedDigestsFor(pieceId)).toHaveLength(0);
    },
  );

  it(
    'still notifies a recipient whose last open predates the batch',
    { timeout: TIMEOUT },
    async () => {
      const pieceId = uniq('p');
      const author = uniq('maya');
      const owner = uniq('owner');
      const token = uniq('tok');
      await seedPiece({
        pieceId,
        ownerId: owner,
        collaborators: [{ uid: author, name: 'Maya' }],
      });
      await db().doc(`deviceTokens/${owner}`).set({ tokens: [token] });
      await db().doc(`pieces/${pieceId}/reads/${owner}`).set({
        uid: owner,
        lastOpenedAt: Timestamp.fromMillis(Date.now() - 60_000),
      });

      await onNoteAnnotationsChanged.run(
        noteEvent(pieceId, uniq('n'), { authorId: author }),
      );
      await drainPushDigestsOnce();

      const calls = callsFor(token);
      expect(calls).toHaveLength(1);
      expect(calls[0].notification?.title).toBe(
        'Maya added 1 note to Clair de Lune',
      );
    },
  );

  it(
    'falls back to "Someone" for an author the piece cannot name',
    { timeout: TIMEOUT },
    async () => {
      const pieceId = uniq('p');
      const author = uniq('anon');
      const owner = uniq('owner');
      const token = uniq('tok');
      await seedPiece({
        pieceId,
        ownerId: owner,
        collaborators: [{ uid: author }],
      });
      await db().doc(`deviceTokens/${owner}`).set({ tokens: [token] });

      await onLayerAnnotationsChanged.run(layerEvent(pieceId, author, 1, 0));
      await drainPushDigestsOnce();

      const calls = callsFor(token);
      expect(calls).toHaveLength(1);
      expect(calls[0].notification?.title).toBe(
        'Someone added 1 note to Clair de Lune',
      );
    },
  );

  it(
    'prunes a dead token via the shared M5.3 send path',
    { timeout: TIMEOUT },
    async () => {
      const pieceId = uniq('p');
      const author = uniq('maya');
      const owner = uniq('owner');
      const deadToken = uniq('dead');
      const liveToken = uniq('live');
      await seedPiece({
        pieceId,
        ownerId: owner,
        collaborators: [{ uid: author, name: 'Maya' }],
      });
      await db()
        .doc(`deviceTokens/${owner}`)
        .set({ tokens: [deadToken, liveToken] });
      sendEachForMulticast.mockImplementation((message) =>
        Promise.resolve({
          responses: message.tokens.map((token) =>
            token === deadToken
              ? {
                  success: false,
                  error: {
                    code: 'messaging/registration-token-not-registered',
                  },
                }
              : { success: true },
          ),
          successCount: 1,
          failureCount: 1,
        } as unknown as BatchResponse),
      );

      await onLayerAnnotationsChanged.run(layerEvent(pieceId, author, 1, 0));
      await drainPushDigestsOnce();

      const tokens = await db().doc(`deviceTokens/${owner}`).get();
      expect(tokens.data()?.tokens).toEqual([liveToken]);
    },
  );
});
