// Executable coverage of ../firestore.rules — the M1.7 harness. Each block
// mirrors a collection's ACL matrix; M2.3 extends this file (or siblings in
// this directory) with the pieces/layers/notes/reads schema.
//
// Runs against the Firestore emulator: `npm test` boots one around vitest
// via `firebase emulators:exec`; `npm run test:against-running` reuses an
// already-running `dev.sh` suite.
import { readFileSync } from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';

const emulatorHost =
  process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
const [host, port] = emulatorHost.split(':');

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-duet',
    firestore: {
      rules: readFileSync(
        new URL('../../firestore.rules', import.meta.url),
        'utf8',
      ),
      host,
      port: Number(port),
    },
  });
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

const sam = () => env.authenticatedContext('uid-sam').firestore();
const mallory = () => env.authenticatedContext('uid-mallory').firestore();
const anon = () => env.unauthenticatedContext().firestore();

/** Seeds [data] at [path] with rules disabled (test fixture setup). */
async function seed(path: string, data: Record<string, unknown>) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

const samEntry = {
  uid: 'uid-sam',
  email: 'sam@example.com',
  displayName: 'Sam',
  discoverable: true,
};

describe('usersByEmail', () => {
  it('a signed-in stranger cannot get any entry — discovery is the '
      + 'rate-limited lookupEmail callable\'s job now (M2.5)', async () => {
    // Even a discoverable entry: cross-user reads are gone from the client.
    await seed('usersByEmail/sam@example.com', samEntry);
    await assertFails(getDoc(doc(mallory(), 'usersByEmail/sam@example.com')));
    // And of course a non-discoverable one.
    await seed('usersByEmail/hidden@example.com', {
      ...samEntry,
      email: 'hidden@example.com',
      discoverable: false,
    });
    await assertFails(
      getDoc(doc(mallory(), 'usersByEmail/hidden@example.com')),
    );
  });

  it('the owner can still get their own entry (discoverable or not)', async () => {
    await seed('usersByEmail/sam@example.com', {
      ...samEntry,
      discoverable: false,
    });
    await assertSucceeds(getDoc(doc(sam(), 'usersByEmail/sam@example.com')));
  });

  it('unauthenticated get is denied', async () => {
    await seed('usersByEmail/sam@example.com', samEntry);
    await assertFails(getDoc(doc(anon(), 'usersByEmail/sam@example.com')));
  });

  it('list/query is always denied — even for a signed-in owner', async () => {
    await seed('usersByEmail/sam@example.com', samEntry);
    await assertFails(getDocs(collection(sam(), 'usersByEmail')));
    await assertFails(getDocs(collection(mallory(), 'usersByEmail')));
  });

  it('the owner can create their own entry', async () => {
    await assertSucceeds(
      setDoc(doc(sam(), 'usersByEmail/sam@example.com'), samEntry),
    );
  });

  it('creating an entry carrying someone else’s uid is denied', async () => {
    await assertFails(
      setDoc(doc(mallory(), 'usersByEmail/mallory@example.com'), samEntry),
    );
  });

  it('the owner can update their own entry', async () => {
    await seed('usersByEmail/sam@example.com', samEntry);
    await assertSucceeds(
      setDoc(doc(sam(), 'usersByEmail/sam@example.com'), {
        ...samEntry,
        displayName: 'Sam D.',
      }),
    );
  });

  it('a stranger cannot hijack an existing mapping by re-pointing its uid '
      + '(invite-hijack regression)', async () => {
    await seed('usersByEmail/sam@example.com', samEntry);
    // Mallory overwrites sam@example.com's entry with her own uid — with
    // the pre-M1.7 rules this passed, silently redirecting Sam's invites.
    await assertFails(
      setDoc(doc(mallory(), 'usersByEmail/sam@example.com'), {
        uid: 'uid-mallory',
        email: 'sam@example.com',
        displayName: 'Sam',
        discoverable: true,
      }),
    );
  });

  it('a stranger cannot update an entry even keeping its uid', async () => {
    await seed('usersByEmail/sam@example.com', samEntry);
    await assertFails(
      setDoc(doc(mallory(), 'usersByEmail/sam@example.com'), {
        ...samEntry,
        displayName: 'Vandalized',
      }),
    );
  });

  it('only the owner may delete their entry', async () => {
    await seed('usersByEmail/sam@example.com', samEntry);
    await assertFails(deleteDoc(doc(mallory(), 'usersByEmail/sam@example.com')));
    await assertSucceeds(deleteDoc(doc(sam(), 'usersByEmail/sam@example.com')));
  });
});

describe('deviceTokens', () => {
  it('a user can read and write their own token doc', async () => {
    await assertSucceeds(
      setDoc(doc(sam(), 'deviceTokens/uid-sam'), { tokens: ['t1'] }),
    );
    await assertSucceeds(getDoc(doc(sam(), 'deviceTokens/uid-sam')));
  });

  it('another user’s token doc is off-limits', async () => {
    await seed('deviceTokens/uid-sam', { tokens: ['t1'] });
    await assertFails(getDoc(doc(mallory(), 'deviceTokens/uid-sam')));
    await assertFails(
      setDoc(doc(mallory(), 'deviceTokens/uid-sam'), { tokens: ['evil'] }),
    );
  });

  it('unauthenticated access is denied', async () => {
    await assertFails(getDoc(doc(anon(), 'deviceTokens/uid-sam')));
  });
});

describe('userInbox', () => {
  const message = {
    toUid: 'uid-sam',
    fromUid: 'uid-mallory',
    type: 'invite',
    read: false,
  };

  it('the recipient can read and update (mark read) a message', async () => {
    await seed('userInbox/uid-sam/messages/m1', message);
    await assertSucceeds(getDoc(doc(sam(), 'userInbox/uid-sam/messages/m1')));
    await assertSucceeds(
      updateDoc(doc(sam(), 'userInbox/uid-sam/messages/m1'), { read: true }),
    );
  });

  it('a non-recipient cannot read someone else’s inbox', async () => {
    await seed('userInbox/uid-sam/messages/m1', message);
    await assertFails(
      getDoc(doc(mallory(), 'userInbox/uid-sam/messages/m1')),
    );
  });

  it('no client may create an inbox message — writes are server-only '
      + '(M2.4 moved sends behind the sendInvite Function)', async () => {
    // A stranger sending spam: denied.
    await assertFails(
      setDoc(doc(mallory(), 'userInbox/uid-sam/messages/m1'), message),
    );
    // Even the recipient writing to their own inbox: denied (only the Admin
    // SDK, bypassing rules, may create).
    await assertFails(
      setDoc(doc(sam(), 'userInbox/uid-sam/messages/m1'), message),
    );
  });

  it('nothing may delete an inbox message — not even the recipient', async () => {
    await seed('userInbox/uid-sam/messages/m1', message);
    await assertFails(deleteDoc(doc(sam(), 'userInbox/uid-sam/messages/m1')));
    await assertFails(
      deleteDoc(doc(mallory(), 'userInbox/uid-sam/messages/m1')),
    );
  });
});

describe('inviteTokens (M5.2) — Function-only, no client access at all', () => {
  // A live token minted by the createInviteToken callable (seeded with rules
  // disabled, standing in for the Admin SDK writer). uid-sam is the owner.
  const tokenDoc = {
    pieceId: 'p1',
    ownerId: 'uid-sam',
    ownerName: 'Sam',
    createdAt: 1,
    expiresAt: 2,
    consumed: false,
    consumedBy: null,
  };

  it('no one may get a token doc — not the owner, an invitee, or anon '
      + '(preview goes through the resolveInviteToken callable)', async () => {
    await seed('inviteTokens/tok-1', tokenDoc);
    await assertFails(getDoc(doc(sam(), 'inviteTokens/tok-1')));
    await assertFails(getDoc(doc(mallory(), 'inviteTokens/tok-1')));
    await assertFails(getDoc(doc(anon(), 'inviteTokens/tok-1')));
  });

  it('no one may list/query tokens (that would enumerate live invite '
      + 'links)', async () => {
    await seed('inviteTokens/tok-1', tokenDoc);
    await assertFails(getDocs(collection(sam(), 'inviteTokens')));
    await assertFails(getDocs(collection(mallory(), 'inviteTokens')));
  });

  it('not even the owner may mint a token doc directly — creation is the '
      + 'createInviteToken callable (owner + cap checked server-side)', async () => {
    await assertFails(setDoc(doc(sam(), 'inviteTokens/tok-1'), tokenDoc));
  });

  it('no client may redeem (update) or revoke (delete) a token — '
      + 'consumption is the acceptInviteToken callable', async () => {
    await seed('inviteTokens/tok-1', tokenDoc);
    // The invitee marking it consumed themselves: denied.
    await assertFails(
      updateDoc(doc(mallory(), 'inviteTokens/tok-1'), {
        consumed: true,
        consumedBy: 'uid-mallory',
      }),
    );
    // The owner revoking by hand: denied (delete rides the piece-delete
    // cascade Function or the expiresAt TTL).
    await assertFails(deleteDoc(doc(sam(), 'inviteTokens/tok-1')));
  });
});

describe('deny-by-default catch-all', () => {
  it('unmatched collections are unreadable and unwritable even signed in', async () => {
    await assertFails(getDoc(doc(sam(), 'somewhereElse/doc1')));
    await assertFails(
      setDoc(doc(sam(), 'somewhereElse/doc1'), { anything: true }),
    );
  });
});
