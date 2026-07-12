import { defineConfig } from 'vitest/config';

// The emulator-backed suites (delete_account, invite_lifecycle) share one
// Firestore emulator and each clears it in `beforeEach`. Running files in
// parallel (vitest's default) lets one file's clear wipe another's fixtures
// mid-test, so run files serially; tests within a file already run in order.
export default defineConfig({
  test: {
    fileParallelism: false,
  },
});
