import { describe, expect, it } from 'vitest';

import { handleProviderRequest } from '../src/calendar_feed_routes';
import type { Env } from '../src/env';

describe('calendar feed route handler', () => {
  it('retires the old OAuth start route with a migration message', async () => {
    const response = await handleProviderRequest(
      new Request('https://momentum.example.com/api/google/oauth/start'),
      {} as Env,
      'google',
      'oauth/start',
    );

    expect(response.status).toBe(410);
    await expect(response.json()).resolves.toEqual({
      error: 'Connect google with a published .ics link.',
    });
  });

  it('returns an unconnected status when there is no active session cookie', async () => {
    const response = await handleProviderRequest(
      new Request('https://momentum.example.com/api/canvas/status'),
      {} as Env,
      'canvas',
      'status',
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ connected: false });
  });

  it('returns a not-found response for unsupported provider endpoints', async () => {
    const response = await handleProviderRequest(
      new Request('https://momentum.example.com/api/outlook/settings'),
      {} as Env,
      'outlook',
      'settings',
    );

    expect(response.status).toBe(404);
    await expect(response.json()).resolves.toEqual({ error: 'Not found.' });
  });
});
