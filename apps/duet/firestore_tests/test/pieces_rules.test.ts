// Executable coverage of ../firestore.rules for the pieces schema (M2.3) —
// the full create/read/update/delete × role matrix for `pieces` and its
// `layers`/`notes`/`reads` subcollections, per docs/duet_cloud_schema.md.
// Sibling of firestore_rules.test.ts (the M1 identity collections); both run
// under `npm test` (test/**/*.test.ts).
//
// Fixtures: `owner` owns piece `p1`; `collab` is its one collaborator;
// `stranger` is a signed-in non-participant; `anon` is unauthenticated.
import { readFileSync } from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
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

afterAll(async () => env.cleanup());
beforeEach(async () => env.clearFirestore());

const owner = () => env.authenticatedContext('uid-owner').firestore();
const collab = () => env.authenticatedContext('uid-collab').firestore();
const stranger = () => env.authenticatedContext('uid-stranger').firestore();
const anon = () => env.unauthenticatedContext().firestore();

function pieceDoc(collaboratorIds: string[]) {
  return {
    title: 'Clair de Lune',
    ownerId: 'uid-owner',
    ownerName: 'Owner',
    participantIds: ['uid-owner', ...collaboratorIds],
    collaborators: collaboratorIds.map((uid) => ({
      uid,
      name: null,
      email: null,
    })),
    basePdfChecksum: 'abc123',
    createdAt: new Date('2024-01-01'),
    updatedAt: new Date('2024-01-02'),
  };
}

/** Seeds piece `p1` (owner + `uid-collab`) and, optionally, extra docs. */
async function seed(
  extra?: (db: import('firebase/firestore').Firestore) => Promise<void>,
) {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'pieces/p1'), pieceDoc(['uid-collab']));
    if (extra) await extra(db);
  });
}

describe('pieces/{id}', () => {
  it('read: participants yes, stranger/anon no', async () => {
    await seed();
    await assertSucceeds(getDoc(doc(owner(), 'pieces/p1')));
    await assertSucceeds(getDoc(doc(collab(), 'pieces/p1')));
    await assertFails(getDoc(doc(stranger(), 'pieces/p1')));
    await assertFails(getDoc(doc(anon(), 'pieces/p1')));
  });

  it('query: a participant-scoped query resolves; an unscoped one is denied', async () => {
    await seed();
    await assertSucceeds(
      getDocs(
        query(
          collection(owner(), 'pieces'),
          where('participantIds', 'array-contains', 'uid-owner'),
        ),
      ),
    );
    // No where-clause → tries to read docs the caller isn't in → denied.
    await assertFails(getDocs(collection(stranger(), 'pieces')));
  });

  it('create: owner as sole participant with no collaborators', async () => {
    await assertSucceeds(
      setDoc(doc(owner(), 'pieces/p2'), pieceDoc([])),
    );
  });

  it('create is denied when pre-seeding a collaborator', async () => {
    await assertFails(
      setDoc(doc(owner(), 'pieces/p2'), pieceDoc(['uid-collab'])),
    );
  });

  it('create is denied when ownerId is not the caller', async () => {
    await assertFails(
      setDoc(doc(stranger(), 'pieces/p2'), pieceDoc([])),
    );
  });

  it('create is denied when participantIds is not exactly [owner]', async () => {
    await assertFails(
      setDoc(doc(owner(), 'pieces/p2'), {
        ...pieceDoc([]),
        participantIds: ['uid-owner', 'uid-ghost'],
      }),
    );
  });

  it('update: owner edits metadata', async () => {
    await seed();
    await assertSucceeds(
      updateDoc(doc(owner(), 'pieces/p1'), { title: 'Renamed' }),
    );
  });

  it('update is denied when it changes participantIds', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(owner(), 'pieces/p1'), {
        participantIds: ['uid-owner', 'uid-collab', 'uid-stranger'],
      }),
    );
  });

  it('update is denied when it changes collaborators', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(owner(), 'pieces/p1'), {
        collaborators: [
          { uid: 'uid-collab', name: null, email: null },
          { uid: 'uid-stranger', name: null, email: null },
        ],
      }),
    );
  });

  it('update is denied when it changes ownerId', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(owner(), 'pieces/p1'), { ownerId: 'uid-collab' }),
    );
  });

  it('update: a collaborator cannot edit metadata (owner-only)', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(collab(), 'pieces/p1'), { title: 'Hijack' }),
    );
  });

  it('delete: owner only', async () => {
    await seed();
    await assertFails(deleteDoc(doc(collab(), 'pieces/p1')));
    await assertFails(deleteDoc(doc(stranger(), 'pieces/p1')));
    await assertSucceeds(deleteDoc(doc(owner(), 'pieces/p1')));
  });
});

describe('pieces/{id}/layers/{uid}', () => {
  const layer = (uid: string, role: string) => ({
    ownerId: uid,
    role,
    strokes: [],
    updatedAt: new Date('2024-01-02'),
    rev: 1,
  });

  it('read: participants yes, stranger no', async () => {
    await seed((db) =>
      setDoc(doc(db, 'pieces/p1/layers/uid-collab'), layer('uid-collab', 'collaborator')),
    );
    await assertSucceeds(getDoc(doc(owner(), 'pieces/p1/layers/uid-collab')));
    await assertSucceeds(getDoc(doc(collab(), 'pieces/p1/layers/uid-collab')));
    await assertFails(getDoc(doc(stranger(), 'pieces/p1/layers/uid-collab')));
  });

  it('write: an author writes only their own layer', async () => {
    await seed();
    await assertSucceeds(
      setDoc(
        doc(collab(), 'pieces/p1/layers/uid-collab'),
        layer('uid-collab', 'collaborator'),
      ),
    );
    // Collaborator cannot write the owner's layer.
    await assertFails(
      setDoc(
        doc(collab(), 'pieces/p1/layers/uid-owner'),
        layer('uid-owner', 'owner'),
      ),
    );
    // A stranger cannot write any layer (not a participant).
    await assertFails(
      setDoc(
        doc(stranger(), 'pieces/p1/layers/uid-stranger'),
        layer('uid-stranger', 'collaborator'),
      ),
    );
  });

  it('delete: the author or the owner (removal cascade), not others', async () => {
    await seed((db) =>
      setDoc(doc(db, 'pieces/p1/layers/uid-collab'), layer('uid-collab', 'collaborator')),
    );
    // A collaborator cannot delete the owner's layer.
    await env.withSecurityRulesDisabled((c) =>
      setDoc(doc(c.firestore(), 'pieces/p1/layers/uid-owner'), layer('uid-owner', 'owner')),
    );
    await assertFails(deleteDoc(doc(collab(), 'pieces/p1/layers/uid-owner')));
    // The owner may delete a collaborator's layer (cascade on removal).
    await assertSucceeds(deleteDoc(doc(owner(), 'pieces/p1/layers/uid-collab')));
  });
});

describe('pieces/{id}/notes/{noteId}', () => {
  const note = (authorId: string) => ({
    id: 'n1',
    authorId,
    audioAssetId: 'a1',
    pageIndex: 0,
    durationMs: 1000,
    region: { pageIndex: 0, left: 0.1, top: 0.1, width: 0.2, height: 0.05 },
    createdAt: new Date('2024-01-02'),
    deletedAt: null,
  });

  it('read: participants yes, stranger no', async () => {
    await seed((db) => setDoc(doc(db, 'pieces/p1/notes/n1'), note('uid-collab')));
    await assertSucceeds(getDoc(doc(owner(), 'pieces/p1/notes/n1')));
    await assertFails(getDoc(doc(stranger(), 'pieces/p1/notes/n1')));
  });

  it('create: only as oneself; a spoofed authorId is denied', async () => {
    await seed();
    await assertSucceeds(
      setDoc(doc(collab(), 'pieces/p1/notes/n1'), note('uid-collab')),
    );
    await assertFails(
      setDoc(doc(collab(), 'pieces/p1/notes/n2'), note('uid-owner')),
    );
  });

  it('update: the author may set deletedAt, and only deletedAt', async () => {
    await seed((db) => setDoc(doc(db, 'pieces/p1/notes/n1'), note('uid-collab')));
    await assertSucceeds(
      updateDoc(doc(collab(), 'pieces/p1/notes/n1'), { deletedAt: new Date() }),
    );
    // Any other field change is denied.
    await assertFails(
      updateDoc(doc(collab(), 'pieces/p1/notes/n1'), { durationMs: 9999 }),
    );
    // A non-author cannot tombstone it.
    await assertFails(
      updateDoc(doc(owner(), 'pieces/p1/notes/n1'), { deletedAt: new Date() }),
    );
  });

  it('delete: never, not even the author', async () => {
    await seed((db) => setDoc(doc(db, 'pieces/p1/notes/n1'), note('uid-collab')));
    await assertFails(deleteDoc(doc(collab(), 'pieces/p1/notes/n1')));
    await assertFails(deleteDoc(doc(owner(), 'pieces/p1/notes/n1')));
  });
});

describe('pieces/{id}/reads/{uid}', () => {
  it('a participant writes and reads only their own watermark', async () => {
    await seed();
    await assertSucceeds(
      setDoc(doc(collab(), 'pieces/p1/reads/uid-collab'), {
        lastOpenedAt: new Date(),
      }),
    );
    await assertSucceeds(getDoc(doc(collab(), 'pieces/p1/reads/uid-collab')));
    // Not someone else's watermark.
    await assertFails(
      setDoc(doc(collab(), 'pieces/p1/reads/uid-owner'), {
        lastOpenedAt: new Date(),
      }),
    );
  });

  it('a stranger cannot write a watermark even under their own uid', async () => {
    await seed();
    await assertFails(
      setDoc(doc(stranger(), 'pieces/p1/reads/uid-stranger'), {
        lastOpenedAt: new Date(),
      }),
    );
  });

  it('collection-group: a user reads only their own watermarks', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'pieces/p1/reads/uid-collab'), {
        uid: 'uid-collab',
        lastOpenedAt: new Date(),
      });
      await setDoc(doc(db, 'pieces/p1/reads/uid-owner'), {
        uid: 'uid-owner',
        lastOpenedAt: new Date(),
      });
    });

    // Their own watermarks across pieces resolve in one query (the library).
    await assertSucceeds(
      getDocs(
        query(
          collectionGroup(collab(), 'reads'),
          where('uid', '==', 'uid-collab'),
        ),
      ),
    );
    // Filtering for someone else's is denied by the collection-group rule.
    await assertFails(
      getDocs(
        query(
          collectionGroup(collab(), 'reads'),
          where('uid', '==', 'uid-owner'),
        ),
      ),
    );
  });
});
