import { describe, expect, it, vi } from 'vitest';

import {
  fetchCanvasPages,
  mapCanvasAssignment,
  mapCanvasEvent,
  normalizeCanvasSiteUrl,
  splitContextBatches,
} from '../src/canvas';
import worker, {
  fetchGooglePages,
  fetchGraphPages,
  mapGoogleEvent,
  mapOutlookEvent,
  cleanupExpiredState,
  type Env,
} from '../src/index';

describe('Canvas import helpers', () => {
  it('only accepts the configured HTTPS Canvas host', () => {
    expect(
      normalizeCanvasSiteUrl('https://canvas.school.edu', 'canvas.school.edu')
        .origin,
    ).toBe('https://canvas.school.edu');
    expect(() =>
      normalizeCanvasSiteUrl('https://other.school.edu', 'canvas.school.edu'),
    ).toThrow(/not enabled/);
    expect(() =>
      normalizeCanvasSiteUrl('http://canvas.school.edu', 'canvas.school.edu'),
    ).toThrow(/not enabled/);
  });

  it('maps timed assignment dates with the timezone offset intact as an instant', () => {
    const assignment = mapCanvasAssignment({
      id: 5,
      context_code: 'course_21',
      title: 'Due item',
      start_at: '2026-10-12T23:00:00-04:00',
      assignment: {
        id: 5,
        name: 'Essay',
        due_at: '2026-10-12T23:00:00-04:00',
        description: '<p>Read prompt</p>',
      },
    });
    expect(assignment).toEqual({
      externalId: 'assignment:course_21:5',
      title: 'Essay',
      due: '2026-10-13T03:00:00.000Z',
      description: '<p>Read prompt</p>',
    });
    expect(mapCanvasAssignment({ title: 'Undated', id: 7 })).toBeNull();
  });

  it('maps all-day and timed events with stable source identifiers', () => {
    expect(
      mapCanvasEvent({
        id: 17,
        title: 'Holiday',
        all_day: true,
        all_day_date: '2026-12-25',
      }),
    ).toEqual({
      externalId: 'event:17',
      title: 'Holiday',
      start: '2026-12-25T00:00:00',
      end: '2026-12-25T00:00:00',
      allDay: true,
      description: '',
      location: null,
    });
    expect(
      mapCanvasEvent({
        id: 18,
        title: 'Seminar',
        start_at: '2026-10-12T23:00:00-04:00',
        end_at: '2026-10-13T00:00:00-04:00',
        location_name: 'Hall B',
      })?.start,
    ).toBe('2026-10-13T03:00:00.000Z');
  });

  it('batches calendar contexts at Canvas limits', () => {
    const contexts = Array.from({ length: 23 }, (_, index) => `course_${index}`);
    const batches = splitContextBatches(contexts, 10);
    expect(batches.map((batch) => batch.length)).toEqual([10, 10, 3]);
    expect(batches.flat()).toEqual(contexts);
  });

  it('fetches every Canvas pagination page and sends the bearer token', async () => {
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        new Response(JSON.stringify([{ id: 1 }]), {
          headers: {
            Link: '<https://canvas.school.edu/api/v1/courses?page=2>; rel="next", <https://canvas.school.edu/api/v1/courses?page=1>; rel="first"',
          },
        }),
      )
      .mockResolvedValueOnce(new Response(JSON.stringify([{ id: 2 }])));
    const rows = await fetchCanvasPages<{ id: number }>(
      new URL('https://canvas.school.edu'),
      'access-token',
      '/api/v1/courses?page=1',
      fetcher,
    );
    expect(rows.map((row) => row.id)).toEqual([1, 2]);
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(fetcher.mock.calls[0][1]?.headers).toEqual({
      Authorization: 'Bearer access-token',
    });
  });

  it('redirects OAuth cancellation back to Momentum without creating a link', async () => {
    const response = await worker.fetch(
      new Request(
        'https://momentum.example.com/api/canvas/oauth/callback?error=access_denied',
      ),
      { APP_ORIGIN: 'https://momentum.example.com' } as Env,
    );
    expect(response.status).toBe(302);
    expect(response.headers.get('Location')).toBe(
      'https://momentum.example.com/?calendar_provider=canvas&canvas_error=authorization_cancelled',
    );
  });

  it('rejects a pagination link outside the configured Canvas host', async () => {
    const fetcher = vi.fn<typeof fetch>().mockResolvedValueOnce(
      new Response(JSON.stringify([{ id: 1 }]), {
        headers: {
          Link: '<https://attacker.example/api/v1/steal>; rel="next"',
        },
      }),
    );
    await expect(
      fetchCanvasPages(
        new URL('https://canvas.school.edu'),
        'access-token',
        '/api/v1/courses',
        fetcher,
      ),
    ).rejects.toThrow(/unsafe pagination/);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('redirects to provider setup with a status when OAuth is not configured', async () => {
    const response = await worker.fetch(
      new Request('https://momentum.example.com/api/google/oauth/start'),
      { APP_ORIGIN: 'https://momentum.example.com' } as Env,
    );
    expect(response.status).toBe(302);
    expect(response.headers.get('Location')).toBe(
      'https://momentum.example.com/?calendar_provider=google&google_error=provider_not_configured',
    );
  });

  it('returns users to setup when Outlook authorization is canceled', async () => {
    const response = await worker.fetch(
      new Request(
        'https://momentum.example.com/api/outlook/oauth/callback?error=access_denied',
      ),
      { APP_ORIGIN: 'https://momentum.example.com' } as Env,
    );
    expect(response.status).toBe(302);
    expect(response.headers.get('Location')).toBe(
      'https://momentum.example.com/?calendar_provider=outlook&outlook_error=authorization_cancelled',
    );
  });

  it('rejects excessive OAuth starts with a retry hint', async () => {
    const apiLimiter = { limit: vi.fn().mockResolvedValue({ success: true }) };
    const oauthLimiter = { limit: vi.fn().mockResolvedValue({ success: false }) };
    const response = await worker.fetch(
      new Request('https://momentum.example.com/api/google/oauth/start', {
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

  it('cleans expired OAuth state, connections, and sessions in one D1 batch', async () => {
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
    expect(prepared).toHaveLength(5);
    expect(prepared.map(({ sql }) => sql).join('\n')).toContain(
      'DELETE FROM provider_oauth_states WHERE expires_at <= ?',
    );
    expect(prepared.map(({ sql }) => sql).join('\n')).toContain(
      'DELETE FROM provider_connections',
    );
    expect(prepared.every(({ values }) => values.length === 1)).toBe(true);
  });

  it('maps Google all-day occurrences with stable per-event IDs', () => {
    expect(
      mapGoogleEvent('primary@example.test', {
        id: 'series_instance_20261012',
        recurringEventId: 'series',
        summary: 'Lecture',
        start: { date: '2026-10-12' },
        end: { date: '2026-10-13' },
      }),
    ).toEqual({
      externalId: 'primary@example.test:series_instance_20261012',
      title: 'Lecture',
      start: '2026-10-12T00:00:00',
      end: '2026-10-12T00:00:00',
      allDay: true,
      description: '',
      location: null,
    });
  });

  it('maps Outlook UTC dates, notes, locations, and all-day ranges', () => {
    expect(
      mapOutlookEvent('calendar-1', {
        id: 'evt-8',
        subject: 'Project day',
        body: { content: 'Bring the draft' },
        start: { dateTime: '2026-10-12T00:00:00.0000000', timeZone: 'UTC' },
        end: { dateTime: '2026-10-13T00:00:00.0000000', timeZone: 'UTC' },
        isAllDay: true,
        location: { displayName: 'Library' },
      }),
    ).toEqual({
      externalId: 'calendar-1:evt-8',
      title: 'Project day',
      start: '2026-10-12T00:00:00',
      end: '2026-10-12T00:00:00',
      allDay: true,
      description: 'Bring the draft',
      location: 'Library',
    });
  });

  it('follows Google and Microsoft pagination links', async () => {
    const fetcher = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({ items: [{ id: 'a' }], nextPageToken: 'next' }),
        ),
      )
      .mockResolvedValueOnce(new Response(JSON.stringify({ items: [{ id: 'b' }] })));
    await expect(
      fetchGooglePages(
        'https://www.googleapis.com/calendar/v3/users/me/calendarList',
        'token',
      ),
    ).resolves.toEqual([{ id: 'a' }, { id: 'b' }]);
    fetcher
      .mockReset()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            value: [{ id: 'a' }],
            '@odata.nextLink':
              'https://graph.microsoft.com/v1.0/me/events?$skip=1',
          }),
        ),
      )
      .mockResolvedValueOnce(new Response(JSON.stringify({ value: [{ id: 'b' }] })));
    await expect(
      fetchGraphPages('https://graph.microsoft.com/v1.0/me/events', 'token'),
    ).resolves.toEqual([{ id: 'a' }, { id: 'b' }]);
    fetcher.mockRestore();
  });
});
