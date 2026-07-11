import { onCall } from 'firebase-functions/v2/https';

import { REGION } from './region';

/**
 * Trivial callable proving the Functions workspace deploys and emulates.
 *
 * Exercise it on the emulator (callable protocol over plain HTTP):
 *
 *   curl -X POST http://127.0.0.1:5001/demo-duet/europe-west1/healthcheck \
 *     -H 'Content-Type: application/json' -d '{"data":{}}'
 *
 * → {"result":{"status":"ok","service":"duet-functions"}}
 */
export const healthcheck = onCall({ region: REGION }, () => ({
  status: 'ok',
  service: 'duet-functions',
}));
