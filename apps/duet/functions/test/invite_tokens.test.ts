import { Timestamp } from 'firebase-admin/firestore';
import type { CallableRequest } from 'firebase-functions/v2/https';
import { describe, expect, it } from 'vitest';

import { db } from '../src/firebase';
import {
  acceptInviteToken,
  createInviteToken,
  resolveInviteToken,
  TOKEN_TTL_DAYS,
} from '../src/inviteTokens';

// Emulator-backed (Firestore only — these callables never touch Auth). Under
// `npm test` the host is exported by `firebase emulators:exec`; the fallback
// serves `npm run test:against-running`.
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.GCLOUD_PROJECT ??= 'demo-duet';
const TIMEOUT = 20_000;

const TTL_MS = TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000;

// No `clearFirestore` here, deliberately — every test seeds under ids unique
// to that test instead. The other suites' fixed-id + clear-all style breaks
// under `test:against-running` when the running suite includes the FUNCTIONS
// emulator: deleting `pieces/{id}` fires the live `onPieceDeleted` cascade,
// whose async `recursiveDelete` can land AFTER the next test re-seeds the
// same id — wiping its fixture (and the clear-all also nukes whatever state
// the live dev session had). Unique ids need no cleanup and make any stale
// cascade harmless. (`emulators:exec --only auth,firestore`, the `npm test`
// path, runs no triggers and never hits the race either way.)
let seq = 0;
const uniq = (prefix: string) => `${prefix}-${Date.now()}-${seq++}`;

type AuthData = NonNullable<CallableRequest['auth']>;

/** A callable request from [uid] (optionally carrying a token name/email). */
function requestFrom(
  uid: string,
  data: unknown,
  identity: { name?: string; email?: string } = {},
): CallableRequest {
  return {
    data,
    acceptsStreaming: false,
    auth: { uid, token: identity } as AuthData,
  } as CallableRequest;
}

const unauthenticated = (data: unknown): CallableRequest =>
  ({ data, acceptsStreaming: false }) as CallableRequest;

/** Creates a `pieces/{pieceId}` doc owned by [ownerId]. */
async function seedPiece(
  pieceId: string,
  ownerId: string,
  {
    collaborators = [] as unknown[],
    ownerName = 'Olivia' as string | null,
  } = {},
) {
  await db()
    .doc(`pieces/${pieceId}`)
    .set({
      ownerId,
      ownerName,
      title: `Title of ${pieceId}`,
      participantIds: [
        ownerId,
        ...collaborators.map((c) => (c as { uid: string }).uid),
      ],
      collaborators,
    });
}

/** Seeds an `inviteTokens/{token}` doc, valid for 14 days by default. */
async function seedToken(
  token: string,
  pieceId: string,
  ownerId: string,
  {
    ownerName = 'Olivia' as string | null,
    consumed = false,
    consumedBy = null as string | null,
    expiresInMs = TTL_MS,
  } = {},
) {
  const now = Timestamp.now();
  await db().doc(`inviteTokens/${token}`).set({
    pieceId,
    ownerId,
    ownerName,
    createdAt: now,
    expiresAt: Timestamp.fromMillis(now.toMillis() + expiresInMs),
    consumed,
    consumedBy,
  });
}

const tokenDoc = async (token: string) =>
  (await db().doc(`inviteTokens/${token}`).get()).data();

const pieceDoc = async (pieceId: string) =>
  (await db().doc(`pieces/${pieceId}`).get()).data();

describe('createInviteToken', () => {
  it('rejects an unauthenticated caller', { timeout: TIMEOUT }, async () => {
    await expect(
      createInviteToken.run(unauthenticated({ pieceId: uniq('p') })),
    ).rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it('rejects a missing pieceId', { timeout: TIMEOUT }, async () => {
    await expect(
      createInviteToken.run(requestFrom(uniq('uid'), {})),
    ).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('rejects a piece that does not exist', { timeout: TIMEOUT }, async () => {
    await expect(
      createInviteToken.run(requestFrom(uniq('uid'), { pieceId: uniq('p') })),
    ).rejects.toMatchObject({ code: 'not-found' });
  });

  it(
    'rejects a caller who does not own the piece',
    { timeout: TIMEOUT },
    async () => {
      const [p, owner] = [uniq('p'), uniq('uid')];
      await seedPiece(p, owner);
      await expect(
        createInviteToken.run(requestFrom(uniq('uid'), { pieceId: p })),
      ).rejects.toMatchObject({ code: 'permission-denied' });
    },
  );

  it(
    'mints a single-use doc expiring in 14 days and returns the URL',
    { timeout: TIMEOUT },
    async () => {
      const [p, owner] = [uniq('p'), uniq('uid')];
      await seedPiece(p, owner);

      const result = (await createInviteToken.run(
        requestFrom(owner, { pieceId: p }, { name: 'Olivia' }),
      )) as { status: string; token: string; url: string };

      expect(result.status).toBe('created');
      expect(result.token).toHaveLength(20);
      expect(result.url).toBe(`https://duet.app/invite/${result.token}`);

      const doc = await tokenDoc(result.token);
      expect(doc).toMatchObject({
        pieceId: p,
        ownerId: owner,
        ownerName: 'Olivia',
        consumed: false,
        consumedBy: null,
      });
      const createdAt = (doc?.createdAt as Timestamp).toMillis();
      const expiresAt = (doc?.expiresAt as Timestamp).toMillis();
      expect(expiresAt - createdAt).toBe(TTL_MS);
    },
  );

  it(
    'rejects an at-cap piece (free tier: 1 collaborator) with a typed code',
    { timeout: TIMEOUT },
    async () => {
      const [p, owner] = [uniq('p'), uniq('uid')];
      await seedPiece(p, owner, {
        collaborators: [{ uid: uniq('uid'), name: null, email: null }],
      });
      await expect(
        createInviteToken.run(requestFrom(owner, { pieceId: p })),
      ).rejects.toMatchObject({
        code: 'resource-exhausted',
        details: { reason: 'at-cap' },
      });
    },
  );

  it(
    'a pro owner (entitlements/{uid}) may mint past the free cap',
    { timeout: TIMEOUT },
    async () => {
      const [p, owner] = [uniq('p'), uniq('uid')];
      await seedPiece(p, owner, {
        collaborators: [{ uid: uniq('uid'), name: null, email: null }],
      });
      await db().doc(`entitlements/${owner}`).set({ pro: true });

      const result = (await createInviteToken.run(
        requestFrom(owner, { pieceId: p }),
      )) as { status: string };
      expect(result.status).toBe('created');
    },
  );
});

describe('resolveInviteToken', () => {
  it('rejects an unauthenticated caller', { timeout: TIMEOUT }, async () => {
    await expect(
      resolveInviteToken.run(unauthenticated({ token: uniq('t') })),
    ).rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it('an unknown token is invalid', { timeout: TIMEOUT }, async () => {
    await expect(
      resolveInviteToken.run(requestFrom(uniq('uid'), { token: uniq('t') })),
    ).rejects.toMatchObject({
      code: 'not-found',
      details: { reason: 'invalid' },
    });
  });

  it('an expired token is rejected as such', { timeout: TIMEOUT }, async () => {
    const [p, t, owner] = [uniq('p'), uniq('t'), uniq('uid')];
    await seedPiece(p, owner);
    await seedToken(t, p, owner, { expiresInMs: -1 });
    await expect(
      resolveInviteToken.run(requestFrom(uniq('uid'), { token: t })),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      details: { reason: 'expired' },
    });
  });

  it(
    'a token consumed by someone else is rejected as used',
    { timeout: TIMEOUT },
    async () => {
      const [p, t, owner] = [uniq('p'), uniq('t'), uniq('uid')];
      await seedPiece(p, owner);
      await seedToken(t, p, owner, {
        consumed: true,
        consumedBy: uniq('uid'),
      });
      await expect(
        resolveInviteToken.run(requestFrom(uniq('uid'), { token: t })),
      ).rejects.toMatchObject({
        code: 'failed-precondition',
        details: { reason: 'consumed' },
      });
    },
  );

  it(
    'a token the caller themself consumed still resolves (re-opened link '
      + 'lands on the already-a-collaborator screen, not a dead error)',
    { timeout: TIMEOUT },
    async () => {
      const [p, t] = [uniq('p'), uniq('t')];
      const [owner, sam] = [uniq('uid'), uniq('uid')];
      await seedPiece(p, owner);
      await seedToken(t, p, owner, { consumed: true, consumedBy: sam });
      const result = await resolveInviteToken.run(
        requestFrom(sam, { token: t }),
      );
      expect(result).toMatchObject({ status: 'resolved', pieceId: p });
    },
  );

  it(
    'resolves piece title + owner without consuming anything',
    { timeout: TIMEOUT },
    async () => {
      const [p, t, owner] = [uniq('p'), uniq('t'), uniq('uid')];
      await seedPiece(p, owner);
      await seedToken(t, p, owner);

      const result = await resolveInviteToken.run(
        requestFrom(uniq('uid'), { token: t }),
      );

      expect(result).toEqual({
        status: 'resolved',
        pieceId: p,
        pieceTitle: `Title of ${p}`,
        ownerId: owner,
        ownerName: 'Olivia',
      });
      expect((await tokenDoc(t))?.consumed).toBe(false);
    },
  );

  it(
    'a token whose piece was deleted is invalid',
    { timeout: TIMEOUT },
    async () => {
      const [t, owner] = [uniq('t'), uniq('uid')];
      await seedToken(t, uniq('p'), owner);
      await expect(
        resolveInviteToken.run(requestFrom(uniq('uid'), { token: t })),
      ).rejects.toMatchObject({
        code: 'not-found',
        details: { reason: 'invalid' },
      });
    },
  );
});

describe('acceptInviteToken', () => {
  it('rejects an unauthenticated caller', { timeout: TIMEOUT }, async () => {
    await expect(
      acceptInviteToken.run(unauthenticated({ token: uniq('t') })),
    ).rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it(
    'happy path: joins the piece and consumes the token, atomically',
    { timeout: TIMEOUT },
    async () => {
      const [p, t] = [uniq('p'), uniq('t')];
      const [owner, sam] = [uniq('uid'), uniq('uid')];
      await seedPiece(p, owner);
      await seedToken(t, p, owner);

      const result = await acceptInviteToken.run(
        requestFrom(sam, {
          token: t,
          accepterName: 'Sam',
          accepterEmail: 's@x.y',
        }),
      );

      expect(result).toEqual({
        status: 'accepted',
        pieceId: p,
        ownerId: owner,
      });
      const piece = await pieceDoc(p);
      expect(piece?.participantIds).toEqual([owner, sam]);
      expect(piece?.collaborators).toContainEqual({
        uid: sam,
        name: 'Sam',
        email: 's@x.y',
      });
      expect(await tokenDoc(t)).toMatchObject({
        consumed: true,
        consumedBy: sam,
      });
    },
  );

  it(
    'a consumed token cannot be reused by a second account',
    { timeout: TIMEOUT },
    async () => {
      const [p, t, owner] = [uniq('p'), uniq('t'), uniq('uid')];
      const [first, second] = [uniq('uid'), uniq('uid')];
      await seedPiece(p, owner);
      await seedToken(t, p, owner);
      await acceptInviteToken.run(requestFrom(first, { token: t }));

      await expect(
        acceptInviteToken.run(requestFrom(second, { token: t })),
      ).rejects.toMatchObject({
        code: 'failed-precondition',
        details: { reason: 'consumed' },
      });
      // The second account never joined.
      expect((await pieceDoc(p))?.participantIds).toEqual([owner, first]);
    },
  );

  it(
    'an expired token is rejected and touches nothing',
    { timeout: TIMEOUT },
    async () => {
      const [p, t, owner] = [uniq('p'), uniq('t'), uniq('uid')];
      await seedPiece(p, owner);
      await seedToken(t, p, owner, { expiresInMs: -1 });

      await expect(
        acceptInviteToken.run(requestFrom(uniq('uid'), { token: t })),
      ).rejects.toMatchObject({
        code: 'failed-precondition',
        details: { reason: 'expired' },
      });
      expect((await pieceDoc(p))?.participantIds).toEqual([owner]);
      expect((await tokenDoc(t))?.consumed).toBe(false);
    },
  );

  it(
    'an at-cap piece (free tier) rejects the accept with a typed code',
    { timeout: TIMEOUT },
    async () => {
      const [p, t, owner] = [uniq('p'), uniq('t'), uniq('uid')];
      await seedPiece(p, owner, {
        collaborators: [{ uid: uniq('uid'), name: null, email: null }],
      });
      await seedToken(t, p, owner);

      await expect(
        acceptInviteToken.run(requestFrom(uniq('uid'), { token: t })),
      ).rejects.toMatchObject({
        code: 'resource-exhausted',
        details: { reason: 'at-cap' },
      });
      // The token survives for after the owner upgrades / frees a slot.
      expect((await tokenDoc(t))?.consumed).toBe(false);
    },
  );

  it(
    'a pro owner (entitlements/{uid}) accepts past the free cap',
    { timeout: TIMEOUT },
    async () => {
      const [p, t] = [uniq('p'), uniq('t')];
      const [owner, sam] = [uniq('uid'), uniq('uid')];
      await seedPiece(p, owner, {
        collaborators: [{ uid: uniq('uid'), name: null, email: null }],
      });
      await db().doc(`entitlements/${owner}`).set({ pro: true });
      await seedToken(t, p, owner);

      const result = await acceptInviteToken.run(
        requestFrom(sam, { token: t }),
      );
      expect(result).toMatchObject({ status: 'accepted' });
      expect((await pieceDoc(p))?.participantIds).toContain(sam);
    },
  );

  it(
    'an existing participant (incl. the owner) gets already-collaborator '
      + 'and the token stays unconsumed',
    { timeout: TIMEOUT },
    async () => {
      const [p, t, owner] = [uniq('p'), uniq('t'), uniq('uid')];
      await seedPiece(p, owner);
      await seedToken(t, p, owner);

      await expect(
        acceptInviteToken.run(requestFrom(owner, { token: t })),
      ).rejects.toMatchObject({
        code: 'already-exists',
        details: { reason: 'already-collaborator' },
      });
      expect((await tokenDoc(t))?.consumed).toBe(false);
    },
  );

  it(
    'backfills a missing piece ownerName from the invite',
    { timeout: TIMEOUT },
    async () => {
      const [p, t, owner] = [uniq('p'), uniq('t'), uniq('uid')];
      await seedPiece(p, owner, { ownerName: null });
      await seedToken(t, p, owner, { ownerName: 'Olivia' });

      await acceptInviteToken.run(requestFrom(uniq('uid'), { token: t }));

      expect((await pieceDoc(p))?.ownerName).toBe('Olivia');
    },
  );
});
