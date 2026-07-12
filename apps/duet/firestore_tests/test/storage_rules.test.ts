// Executable coverage of ../storage.rules (M2.3), per docs/duet_cloud_schema.md.
// Storage membership is a CROSS-SERVICE read — the rules resolve the piece's
// `participantIds`/`ownerId` via `firestore.get(...)` — so these tests need
// BOTH the Storage and Firestore emulators up (`npm test` boots both) and seed
// the gating piece document in Firestore first.
import { readFileSync } from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';
import { getBytes, ref, uploadBytes } from 'firebase/storage';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
const [fsHost, fsPort] = firestoreHost.split(':');
const storageHost =
  process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? '127.0.0.1:9199';
const [stHost, stPort] = storageHost.split(':');

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-duet',
    firestore: {
      rules: readFileSync(
        new URL('../../firestore.rules', import.meta.url),
        'utf8',
      ),
      host: fsHost,
      port: Number(fsPort),
    },
    storage: {
      rules: readFileSync(
        new URL('../../storage.rules', import.meta.url),
        'utf8',
      ),
      host: stHost,
      port: Number(stPort),
    },
  });
});

afterAll(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  // The gating piece: owner uid-owner, one collaborator uid-collab.
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'pieces/p1'), {
      title: 'Clair de Lune',
      ownerId: 'uid-owner',
      participantIds: ['uid-owner', 'uid-collab'],
      collaborators: [{ uid: 'uid-collab', name: null, email: null }],
      basePdfChecksum: 'abc123',
      createdAt: new Date('2024-01-01'),
      updatedAt: new Date('2024-01-02'),
    });
  });
});

const owner = () => env.authenticatedContext('uid-owner').storage();
const collab = () => env.authenticatedContext('uid-collab').storage();
const stranger = () => env.authenticatedContext('uid-stranger').storage();

const tiny = new Uint8Array([1, 2, 3]);
/** One byte over the 5 MB audio cap. */
const overAudioCap = new Uint8Array(5 * 1024 * 1024 + 1);

/** Seeds an object at [path] with rules disabled (fixture setup). */
async function seedObject(path: string) {
  await env.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(ref(context.storage(), path), tiny);
  });
}

describe('storage: pieces/{id}/base.pdf', () => {
  it('read: participants yes, stranger no', async () => {
    await seedObject('pieces/p1/base.pdf');
    await assertSucceeds(getBytes(ref(owner(), 'pieces/p1/base.pdf')));
    await assertSucceeds(getBytes(ref(collab(), 'pieces/p1/base.pdf')));
    await assertFails(getBytes(ref(stranger(), 'pieces/p1/base.pdf')));
  });

  it('write: the owner may, a collaborator (non-owner) may not', async () => {
    await assertSucceeds(
      uploadBytes(ref(owner(), 'pieces/p1/base.pdf'), tiny),
    );
    await assertFails(
      uploadBytes(ref(collab(), 'pieces/p1/base.pdf'), tiny),
    );
    await assertFails(
      uploadBytes(ref(stranger(), 'pieces/p1/base.pdf'), tiny),
    );
  });
});

describe('storage: pieces/{id}/audio/{assetId}', () => {
  it('write: any participant may add a recording; a stranger may not', async () => {
    await assertSucceeds(
      uploadBytes(ref(collab(), 'pieces/p1/audio/a1'), tiny),
    );
    await assertSucceeds(
      uploadBytes(ref(owner(), 'pieces/p1/audio/a2'), tiny),
    );
    await assertFails(
      uploadBytes(ref(stranger(), 'pieces/p1/audio/a3'), tiny),
    );
  });

  it('write over the 5 MB cap is rejected even for a participant', async () => {
    // The base.pdf 50 MB cap is the identical `request.resource.size <`
    // predicate; the audio cap exercises the mechanism without a 50 MB
    // upload in CI.
    await assertFails(
      uploadBytes(ref(collab(), 'pieces/p1/audio/big'), overAudioCap),
    );
  });
});

describe('storage: outside a piece tree', () => {
  it('is denied by default', async () => {
    await assertFails(uploadBytes(ref(owner(), 'somewhere/else.txt'), tiny));
  });
});
