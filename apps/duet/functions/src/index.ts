/**
 * Duet Cloud Functions entry point.
 *
 * Every deployed function is exported from here (the Firebase CLI discovers
 * them via this barrel). Keep one file per function/domain under src/ and
 * re-export; pin every function to the shared region (src/region.ts).
 */
export { healthcheck } from './healthcheck';
