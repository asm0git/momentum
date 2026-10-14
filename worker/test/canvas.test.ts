import { describe, expect, it, vi } from 'vitest';

import worker, {
  cleanupExpiredState,
  type Env,
} from '../src/index';

describe('Calendar provider routes', () => {
  it('does not dispatch an unsupported provider segment', async () => {
    const request = new Request('https://momentum.example.com/api/unknown/status');
    const assets = { fetch: vi.fn(async () => new Response('asset')) };

    const response = await worker.fetch(request, { ASSETS: assets } as unknown as Env);

    expect(response.status).toBe(200);
    expect(await response.text()).toBe('asset');
    expect(assets.fetch).toHaveBeenCalledWith(request);
  });

  it('rejects the retired Canvas OAuth callback', async () => {
    const response = await worker.fetch(
      new Request(
        'https://momentum.example.com/api/canvas/oauth/callback?error=access_denied',
      ),
      { APP_ORIGIN: 'https://momentum.example.com' } as Env,
    );
    expect(response.status).toBe(410);
    expect(await response.json()).toEqual({
      error: 'Calendar OAuth is no longer used.',
    });
  });

  it('directs Google users to use a published feed instead of OAuth', async () => {
    const response = await worker.fetch(
      new Request('https://momentum.example.com/api/google/oauth/start'),
      { APP_ORIGIN: 'https://momentum.example.com' } as Env,
    );
    expect(response.status).toBe(410);
    expect(await response.json()).toEqual({
      error: 'Connect google with a published .ics link.',
    });
  });

  it('rejects the retired Outlook OAuth callback', async () => {
    const response = await worker.fetch(
      new Request(
        'https://momentum.example.com/api/outlook/oauth/callback?error=access_denied',
      ),
      { APP_ORIGIN: 'https://momentum.example.com' } as Env,
    );
    expect(response.status).toBe(410);
    expect(await response.json()).toEqual({
      error: 'Calendar OAuth is no longer used.',
    });
  });

  it('rejects excessive OAuth starts with a retry hint', async () => {
    const apiLimiter = { limit: vi.fn().mockResolvedValue({ success: true }) };
    const oauthLimiter = { limit: vi.fn().mockResolvedValue({ success: false }) };
    const response = await worker.fetch(
      new Request('https://momentum.example.com/api/canvas/oauth/start', {
        headers: { 'cf-connecting-ip': '198.51.100.10' },
      }),
      {
        APP_ORIGIN: 'https://momentum.example.com',
        API_RATE_LIMITER: apiLimiter,
        OAUTH_RATE_LIMITER: oauthLimiter,
      } as unknown as Env,
    );
    expect(response.status).toBe(429);
    expect(response.headers.get('Retry-After')).toBe('60');
    expect(apiLimiter.limit).toHaveBeenCalledWith({ key: 'api:198.51.100.10' });
    expect(oauthLimiter.limit).toHaveBeenCalledWith({ key: 'oauth:198.51.100.10' });
  });

  it('rate limits calendar sync by the browser session', async () => {
    const apiLimiter = { limit: vi.fn().mockResolvedValue({ success: true }) };
    const syncLimiter = { limit: vi.fn().mockResolvedValue({ success: false }) };
    const response = await worker.fetch(
      new Request('https://momentum.example.com/api/google/sync', {
        method: 'POST',
        headers: {
          Origin: 'https://momentum.example.com',
          Cookie: '__Host-momentum_session=session-123',
          'cf-connecting-ip': '198.51.100.10',
        },
      }),
      {
        APP_ORIGIN: 'https://momentum.example.com',
        API_RATE_LIMITER: apiLimiter,
        SYNC_RATE_LIMITER: syncLimiter,
      } as unknown as Env,
    );
    expect(response.status).toBe(429);
    expect(syncLimiter.limit).toHaveBeenCalledWith({ key: 'sync:session-123' });
  });

  it('rejects a state-changing browser-session request without an Origin', async () => {
    const response = await worker.fetch(
      new Request('https://momentum.example.com/api/google/sync', {
        method: 'POST',
        headers: { Cookie: '__Host-momentum_session=session-123' },
      }),
      { APP_ORIGIN: 'https://momentum.example.com' } as Env,
    );

    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({
      error: 'Origin header required for state-changing requests.',
    });
  });

  it('checks mutation Origin against APP_ORIGIN, not the Worker request URL', async () => {
    const response = await worker.fetch(
      new Request('https://momentum.example.com/api/google/sync', {
        method: 'POST',
        headers: { Origin: 'https://momentum.example.com' },
      }),
      { APP_ORIGIN: 'https://app.momentum.example.com' } as Env,
    );

    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({
      error: 'Cross-origin request rejected.',
    });
  });

  it('cleans expired calendar feeds and sessions in one D1 batch', async () => {
    const prepared: Array<{ sql: string; values: unknown[] }> = [];
    const db = {
      prepare(sql: string) {
        const statement = {
          sql,
          values: [] as unknown[],
          bind(...values: unknown[]) {
            this.values = values;
            return this;
          },
        };
        prepared.push(statement);
        return statement;
      },
      batch: vi.fn(async () => []),
    } as unknown as D1Database;

    await cleanupExpiredState(db);

    expect(db.batch).toHaveBeenCalledTimes(1);
    expect(prepared).toHaveLength(2);
    expect(prepared.map(({ sql }) => sql).join('\n')).toContain(
      'DELETE FROM calendar_ics_feeds',
    );
    expect(prepared.map(({ sql }) => sql).join('\n')).not.toContain('oauth_states');
    expect(prepared.map(({ sql }) => sql).join('\n')).not.toContain('canvas_connections');
    expect(prepared.every(({ values }) => values.length === 1)).toBe(true);
  });

});
