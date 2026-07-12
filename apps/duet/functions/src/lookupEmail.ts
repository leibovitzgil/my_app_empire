import * as logger from 'firebase-functions/logger';
import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from './firebase';
import { REGION } from './region';

/**
 * App Check enforcement is env-driven so it stays **off on the emulator**
 * (Track A tests have no App Check token). Turning it on — and flipping console
 * enforcement for Firestore/Functions in staging then prod — is the Track B /
 * [HUMAN] step (see task M2.5 step 2; M0.3 sets up the monitoring).
 */
const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === 'true';

/** Per-caller lookup budget: [RATE_LIMIT] calls per [WINDOW_MS]. */
const RATE_LIMIT = 20;
const WINDOW_MS = 60_000;

const emailKey = (email: string) => email.trim().toLowerCase();

interface LookupEmailData {
  email?: unknown;
}

/**
 * Resolves a discoverable account by email (task M2.5), the server-side,
 * rate-limited replacement for the client's direct `usersByEmail` read.
 *
 * Same semantics as `FirestoreUserDirectory.lookupByEmail`: an exact-key GET
 * honoring the target's own `discoverable` flag, returning `null` for an absent
 * *and* a non-discoverable account alike (indistinguishable — no enumeration).
 * Moving discovery here lets the rules drop `usersByEmail get` to self-only, so
 * a client can no longer read (or brute-force) other users' entries directly;
 * this callable bounds enumeration with a per-caller windowed rate limit.
 */
export const lookupEmail = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (request.auth == null) {
      throw new HttpsError('unauthenticated', 'Sign in to look up a user.');
    }
    const { email } = (request.data ?? {}) as LookupEmailData;
    if (typeof email !== 'string' || email.length === 0) {
      throw new HttpsError('invalid-argument', 'An email is required.');
    }

    await enforceRateLimit(request.auth.uid);

    const entry = (
      await db().doc(`usersByEmail/${emailKey(email)}`).get()
    ).data();
    if (entry == null || entry.discoverable !== true) {
      return { user: null };
    }
    return {
      user: {
        uid: entry.uid as string,
        email: entry.email as string,
        displayName: (entry.displayName as string | undefined) ?? null,
        discoverable: true,
      },
    };
  },
);

/**
 * Trips a `resource-exhausted` error once [uid] exceeds [RATE_LIMIT] calls in a
 * rolling [WINDOW_MS] window. State lives in `rateLimits/{uid}` (a fixed
 * window: `{windowStart, count}`), mutated in a transaction so concurrent calls
 * can't race past the cap. The collection is server-only — clients never touch
 * it (deny-by-default in the rules).
 */
async function enforceRateLimit(uid: string): Promise<void> {
  const ref = db().doc(`rateLimits/${uid}`);
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const data = snap.data() as
      | { windowStart?: Timestamp; count?: number }
      | undefined;
    const windowStart = data?.windowStart?.toMillis() ?? 0;

    if (now - windowStart >= WINDOW_MS) {
      tx.set(ref, { windowStart: Timestamp.fromMillis(now), count: 1 });
      return;
    }
    if ((data?.count ?? 0) >= RATE_LIMIT) {
      throw new HttpsError(
        'resource-exhausted',
        'Too many lookups. Please wait a minute and try again.',
      );
    }
    tx.update(ref, { count: (data?.count ?? 0) + 1 });
  });
  logger.debug('lookupEmail: within rate limit', { uid });
}
