import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { getStorage } from 'firebase-admin/storage';

/**
 * Lazily initialized Admin SDK singletons.
 *
 * Initialization happens at first call, not at import: the CLI's
 * deploy-time discovery imports the barrel without credentials, and tests
 * get to point `FIRESTORE_EMULATOR_HOST` / `FIREBASE_AUTH_EMULATOR_HOST`
 * at the emulators before the first real use.
 */
export const app = () => getApps()[0] ?? initializeApp();

/** The default Firestore database, initializing the app on first use. */
export const db = () => getFirestore(app());

/** The Admin Auth client, initializing the app on first use. */
export const adminAuth = () => getAuth(app());

/**
 * The FCM Messaging client, initializing the app on first use.
 *
 * There is no FCM emulator: tests mock `firebase-admin/messaging` at the
 * module level (see `test/inbox_push.test.ts`); real delivery verification
 * is Track B.
 */
export const fcm = () => getMessaging(app());

/**
 * The default Cloud Storage bucket, initializing the app on first use.
 *
 * Deployed, the bucket name comes from the runtime's `FIREBASE_CONFIG`; in a
 * unit test with no bucket configured, `.bucket()` throws synchronously, so
 * callers that only need best-effort cleanup (the delete cascade) wrap it.
 */
export const bucket = () => getStorage(app()).bucket();
