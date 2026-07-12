import { defineConfig } from 'vitest/config';

// All test files share one Firestore+Storage emulator instance and each
// clears it in `beforeEach`. Running files in parallel (vitest's default)
// lets one file's clear wipe another's seeded fixtures mid-test. Run files
// serially so the shared emulator isn't stomped; tests within a file already
// run sequentially.
export default defineConfig({
  test: {
    fileParallelism: false,
  },
});
