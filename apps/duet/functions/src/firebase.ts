import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

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
