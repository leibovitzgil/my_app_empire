import type { CallableRequest } from 'firebase-functions/v2/https';
import { describe, expect, it } from 'vitest';

import { healthcheck } from '../src/healthcheck';
import { healthcheck as exported } from '../src/index';
import { REGION } from '../src/region';

// v2 callables expose `run` for unit tests; only `data` matters here, so a
// minimal request stub is cast into shape.
const request = (data: unknown): CallableRequest =>
  ({ data, acceptsStreaming: false }) as CallableRequest;

describe('healthcheck', () => {
  it('answers ok', async () => {
    const result = await healthcheck.run(request({}));
    expect(result).toEqual({ status: 'ok', service: 'duet-functions' });
  });

  it('is exported from the entry point barrel', () => {
    expect(exported).toBe(healthcheck);
  });

  it('is pinned to the shared region', () => {
    expect(healthcheck.__endpoint.region).toEqual([REGION]);
  });
});
