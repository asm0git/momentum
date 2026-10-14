import { afterEach, describe, expect, it, vi } from 'vitest';

import worker, { type Env } from '../src/index';
import { parseCalendarIcs } from '../src/ics_calendar_parser';
import {
  CalendarIcsError,
  fetchCalendarIcsEvents,
  normalizeCalendarIcsUrl,
} from '../src/ics_calendar';
import { decrypt, encrypt, fingerprint } from '../src/security';

const canvasFeedUrl =
  'https://canvas.school.instructure.com/feeds/calendars/user_123.ics?verifier=private-token';

interface MockCalendarFeed {
  session_id: string;
  provider: 'canvas' | 'google' | 'outlook';
  remote_user_id: string;
  encrypted_feed_url: string;
  last_sync_time: string | null;
}

interface MockStatementCall {
  sql: string;
  values: unknown[];
}

function createMockDatabase(options: {
  sessionId?: string | null;
  feed?: MockCalendarFeed | null;
} = {}): { db: D1Database; statements: MockStatementCall[] } {
  const statements: MockStatementCall[] = [];
  const db = {
    prepare(sql: string) {
      const call: MockStatementCall = { sql, values: [] };
      statements.push(call);
      return {
        bind(...values: unknown[]) {
          call.values = values;
          return this;
        },
        async first<T>() {
          if (sql.includes('FROM sessions')) {
            return options.sessionId
              ? { session_id: options.sessionId } as T
              : null;
          }
          if (sql.includes('FROM calendar_ics_feeds')) {
            return (options.feed ?? null) as T | null;
          }
          return null;
        },
        async run() {
          return {};
        },
      };
    },
  } as unknown as D1Database;
  return { db, statements };
}

afterEach(() => {
  vi.restoreAllMocks();
  vi.useRealTimers();
});

describe('iCalendar event parsing', () => {
  it('maps event fields and decodes escaped text', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'));

    expect(parseCalendarIcs([
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'BEGIN:VEVENT',
      'UID:study-session',
      'DTSTART:20261015T090000Z',
      'DTEND:20261015T100000Z',
      'SUMMARY:Planning\\, focus',
      'DESCRIPTION:Bring a notebook\\nand review\\; notes',
      'LOCATION:Room 4',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n'))).toEqual([{
      externalId: 'ics:study-session:single',
      title: 'Planning, focus',
      start: '2026-10-15T09:00:00.000Z',
      end: '2026-10-15T10:00:00.000Z',
      allDay: false,
      description: 'Bring a notebook\nand review; notes',
      location: 'Room 4',
    }]);
  });

  it('converts week, day, and clock components of an event duration', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'));

    const [event] = parseCalendarIcs([
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'BEGIN:VEVENT',
      'UID:duration-components',
      'DTSTART:20261015T090000Z',
      'DURATION:P1W2DT3H4M5S',
      'SUMMARY:Duration event',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n'));

    expect(event.end).toBe('2026-10-24T12:04:05.000Z');
  });

  it('expands recurrence rules and omits excluded occurrences', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'));

    const events = parseCalendarIcs([
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'BEGIN:VEVENT',
      'UID:daily-review',
      'DTSTART:20261015T090000Z',
      'DTEND:20261015T093000Z',
      'RRULE:FREQ=DAILY;COUNT=3',
      'EXDATE:20261016T090000Z',
      'SUMMARY:Daily review',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n'));

    expect(events.map(({ externalId, start }) => ({ externalId, start }))).toEqual([
      {
        externalId: 'ics:daily-review:20261015T090000',
        start: '2026-10-15T09:00:00.000Z',
      },
      {
        externalId: 'ics:daily-review:20261017T090000',
        start: '2026-10-17T09:00:00.000Z',
      },
    ]);
  });

  it.each([
    {
      frequency: 'weekly',
      start: '20261019',
      rule: 'FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4',
      dates: ['2026-10-19', '2026-10-21', '2026-10-26', '2026-10-28'],
    },
    {
      frequency: 'monthly',
      start: '20261015',
      rule: 'FREQ=MONTHLY;COUNT=3',
      dates: ['2026-10-15', '2026-11-15', '2026-12-15'],
    },
    {
      frequency: 'yearly',
      start: '20261015',
      rule: 'FREQ=YEARLY;COUNT=2',
      dates: ['2026-10-15', '2027-10-15'],
    },
  ])('expands $frequency recurrence rules', ({ start, rule, dates }) => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'));

    const events = parseCalendarIcs([
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'BEGIN:VEVENT',
      'UID:recurrence-frequency',
      `DTSTART:${start}T090000Z`,
      `DTEND:${start}T100000Z`,
      `RRULE:${rule}`,
      'SUMMARY:Recurring event',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n'));

    expect(events.map(({ start: eventStart }) => eventStart.slice(0, 10))).toEqual(dates);
  });

  it('moves an overridden occurrence and omits a cancelled occurrence', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'));

    const events = parseCalendarIcs([
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'BEGIN:VEVENT',
      'UID:daily-standup',
      'DTSTART:20261015T090000Z',
      'DTEND:20261015T100000Z',
      'RRULE:FREQ=DAILY;COUNT=3',
      'SUMMARY:Daily standup',
      'END:VEVENT',
      'BEGIN:VEVENT',
      'UID:daily-standup',
      'RECURRENCE-ID:20261016T090000Z',
      'DTSTART:20261020T120000Z',
      'DTEND:20261020T130000Z',
      'SUMMARY:Moved standup',
      'END:VEVENT',
      'BEGIN:VEVENT',
      'UID:daily-standup',
      'RECURRENCE-ID:20261017T090000Z',
      'STATUS:CANCELLED',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n'));

    expect(events.map(({ externalId, title, start }) => ({ externalId, title, start })))
      .toEqual([
        {
          externalId: 'ics:daily-standup:20261015T090000',
          title: 'Daily standup',
          start: '2026-10-15T09:00:00.000Z',
        },
        {
          externalId: 'ics:daily-standup:20261016T090000',
          title: 'Moved standup',
          start: '2026-10-20T12:00:00.000Z',
        },
      ]);
  });

  it('expands explicit RDATE occurrences', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'));

    const events = parseCalendarIcs([
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'BEGIN:VEVENT',
      'UID:extra-sessions',
      'DTSTART:20261015T090000Z',
      'DTEND:20261015T100000Z',
      'RDATE:20261020T090000Z,20261022T090000Z',
      'SUMMARY:Extra session',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n'));

    expect(events.map(({ externalId, start }) => ({ externalId, start }))).toEqual([
      {
        externalId: 'ics:extra-sessions:20261015T090000',
        start: '2026-10-15T09:00:00.000Z',
      },
      {
        externalId: 'ics:extra-sessions:20261020T090000',
        start: '2026-10-20T09:00:00.000Z',
      },
      {
        externalId: 'ics:extra-sessions:20261022T090000',
        start: '2026-10-22T09:00:00.000Z',
      },
    ]);
  });

  it('keeps a timezone-aware daily recurrence at the same local wall time', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'));

    const events = parseCalendarIcs([
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'BEGIN:VEVENT',
      'UID:timezone-daily',
      'DTSTART;TZID=America/New_York:20260307T090000',
      'DTEND;TZID=America/New_York:20260307T100000',
      'RRULE:FREQ=DAILY;COUNT=3',
      'SUMMARY:Timezone-aware daily event',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n'));

    expect(events.map(({ externalId, start }) => ({ externalId, start }))).toEqual([
      {
        externalId: 'ics:timezone-daily:20260307T090000',
        start: '2026-03-07T14:00:00.000Z',
      },
      {
        externalId: 'ics:timezone-daily:20260308T090000',
        start: '2026-03-08T13:00:00.000Z',
      },
      {
        externalId: 'ics:timezone-daily:20260309T090000',
        start: '2026-03-09T13:00:00.000Z',
      },
    ]);
  });

  it('converts an event across the New York spring DST boundary', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'));

    const [event] = parseCalendarIcs([
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'BEGIN:VEVENT',
      'UID:dst-transition',
      'DTSTART;TZID=America/New_York:20260308T013000',
      'DTEND;TZID=America/New_York:20260308T033000',
      'SUMMARY:DST transition',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n'));

    expect(event).toMatchObject({
      start: '2026-03-08T06:30:00.000Z',
      end: '2026-03-08T07:30:00.000Z',
    });
  });

  it('preserves a floating local time without adding a timezone suffix', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'));

    const [event] = parseCalendarIcs([
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'BEGIN:VEVENT',
      'UID:floating-event',
      'DTSTART:20261020T090000',
      'DTEND:20261020T100000',
      'SUMMARY:Floating event',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n'));

    expect(event).toMatchObject({
      start: '2026-10-20T09:00:00',
      end: '2026-10-20T10:00:00',
    });
  });

  it('drops event dates with invalid calendar fields', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'));

    const events = parseCalendarIcs([
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'BEGIN:VEVENT',
      'UID:invalid-date',
      'DTSTART:20260230T100000Z',
      'DTEND:20260230T110000Z',
      'SUMMARY:Invalid date',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n'));

    expect(events).toEqual([]);
  });
});

describe('calendar feed sync', () => {
  it('returns parsed events and records the successful sync time', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'));

    const sessionId = 'session-123';
    const encryptionKey = btoa(String.fromCharCode(...new Uint8Array(32).fill(7)));
    const feed = {
      session_id: sessionId,
      provider: 'canvas',
      remote_user_id: 'feed-fingerprint',
      encrypted_feed_url: await encrypt(canvasFeedUrl, encryptionKey),
      last_sync_time: null,
    };
    const statements: Array<{ sql: string; values: unknown[] }> = [];
    const db = {
      prepare(sql: string) {
        const statement = {
          sql,
          values: [] as unknown[],
          bind(...values: unknown[]) {
            this.values = values;
            return this;
          },
          async first<T>() {
            if (sql.includes('FROM sessions')) {
              return { session_id: sessionId } as T;
            }
            if (sql.includes('FROM calendar_ics_feeds')) return feed as T;
            return null;
          },
          async run() {
            statements.push({ sql, values: [...this.values] });
            return {};
          },
        };
        return statement;
      },
    } as unknown as D1Database;
    const fetcher = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response([
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'BEGIN:VEVENT',
        'UID:sync-event',
        'DTSTART:20261015T090000Z',
        'DTEND:20261015T100000Z',
        'SUMMARY:Synced planning',
        'END:VEVENT',
        'END:VCALENDAR',
      ].join('\r\n'), {
        status: 200,
        headers: { 'Content-Type': 'text/calendar' },
      }),
    );

    const response = await worker.fetch(
      new Request('https://momentum.example.com/api/canvas/sync', {
        method: 'POST',
        headers: {
          Origin: 'https://momentum.example.com',
          Cookie: `__Host-momentum_session=${sessionId}`,
        },
      }),
      {
        APP_ORIGIN: 'https://momentum.example.com',
        ALLOWED_CANVAS_HOST: 'canvas.school.edu',
        TOKEN_ENCRYPTION_KEY: encryptionKey,
        DB: db,
      } as Env,
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      accountName: 'Canvas calendar feed',
      accountEmail: null,
      remoteUserId: 'feed-fingerprint',
      providerUrl: 'canvas-published-ics',
      providerName: 'canvas',
      tasks: [],
      events: [{
        externalId: 'ics:sync-event:single',
        title: 'Synced planning',
        start: '2026-10-15T09:00:00.000Z',
        end: '2026-10-15T10:00:00.000Z',
      }],
    });
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(fetcher.mock.calls[0][0]?.toString()).toBe(canvasFeedUrl);
    expect(statements).toEqual([{
      sql: expect.stringContaining('UPDATE calendar_ics_feeds SET last_sync_time'),
      values: ['2026-10-14T00:00:00.000Z', sessionId, 'canvas'],
    }]);
  });
});

describe('calendar feed lifecycle', () => {
  const encryptionKey = btoa(String.fromCharCode(...new Uint8Array(32).fill(7)));

  it('stores an encrypted feed URL and fingerprint when connecting', async () => {
    const { db, statements } = createMockDatabase();
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nEND:VCALENDAR', {
        status: 200,
        headers: { 'Content-Type': 'text/calendar' },
      }),
    );

    const response = await worker.fetch(
      new Request('https://momentum.example.com/api/canvas/connect', {
        method: 'POST',
        headers: {
          Origin: 'https://momentum.example.com',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ url: canvasFeedUrl }),
      }),
      {
        APP_ORIGIN: 'https://momentum.example.com',
        ALLOWED_CANVAS_HOST: 'canvas.school.edu',
        TOKEN_ENCRYPTION_KEY: encryptionKey,
        DB: db,
      } as Env,
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ connected: true });
    const cookie = response.headers.get('Set-Cookie');
    expect(cookie).toContain('__Host-momentum_session=');
    expect(cookie).toContain('HttpOnly');
    const sessionId = cookie?.match(/__Host-momentum_session=([^;]+)/)?.[1];
    expect(sessionId).toBeTruthy();

    const insert = statements.find(({ sql }) => sql.includes('INSERT INTO calendar_ics_feeds'));
    expect(insert).toBeDefined();
    expect(insert?.values[0]).toBe(sessionId);
    expect(insert?.values[1]).toBe('canvas');
    expect(insert?.values[2]).toBe(await fingerprint(canvasFeedUrl));
    expect(insert?.values[3]).not.toBe(canvasFeedUrl);
    expect(await decrypt(String(insert?.values[3]), encryptionKey)).toBe(canvasFeedUrl);
  });

  it('returns stored feed status and removes the connection on disconnect', async () => {
    const sessionId = 'lifecycle-session';
    const feed: MockCalendarFeed = {
      session_id: sessionId,
      provider: 'canvas',
      remote_user_id: 'feed-fingerprint',
      encrypted_feed_url: await encrypt(canvasFeedUrl, encryptionKey),
      last_sync_time: '2026-10-14T00:00:00.000Z',
    };
    const { db, statements } = createMockDatabase({ sessionId, feed });
    const env = {
      APP_ORIGIN: 'https://momentum.example.com',
      DB: db,
    } as Env;
    const cookie = `__Host-momentum_session=${sessionId}`;

    const status = await worker.fetch(
      new Request('https://momentum.example.com/api/canvas/status', {
        headers: { Cookie: cookie },
      }),
      env,
    );
    expect(status.status).toBe(200);
    expect(await status.json()).toEqual({
      connected: true,
      providerUrl: 'canvas-published-ics',
      accountName: 'Canvas calendar feed',
      remoteUserId: 'feed-fingerprint',
      lastSyncTime: '2026-10-14T00:00:00.000Z',
    });

    const disconnected = await worker.fetch(
      new Request('https://momentum.example.com/api/canvas/disconnect', {
        method: 'POST',
        headers: {
          Origin: 'https://momentum.example.com',
          Cookie: cookie,
        },
      }),
      env,
    );
    expect(disconnected.status).toBe(200);
    expect(await disconnected.json()).toEqual({ disconnected: true });
    expect(statements).toContainEqual({
      sql: expect.stringContaining('DELETE FROM calendar_ics_feeds'),
      values: [sessionId, 'canvas'],
    });
  });

  it('rejects sync for a missing session without contacting the feed provider', async () => {
    const { db, statements } = createMockDatabase({ sessionId: null });
    const fetcher = vi.spyOn(globalThis, 'fetch');

    const response = await worker.fetch(
      new Request('https://momentum.example.com/api/google/sync', {
        method: 'POST',
        headers: {
          Origin: 'https://momentum.example.com',
          Cookie: '__Host-momentum_session=expired-session',
        },
      }),
      {
        APP_ORIGIN: 'https://momentum.example.com',
        DB: db,
      } as Env,
    );

    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: 'Connect google first.' });
    expect(fetcher).not.toHaveBeenCalled();
    expect(statements.some(({ sql }) => sql.includes('FROM calendar_ics_feeds')))
      .toBe(false);
  });
});

describe('Canvas calendar feed failures', () => {
  it('returns a 502 and safe diagnostics when Canvas denies the Worker fetch', async () => {
    const fetcher = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response(null, {
        status: 403,
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      }),
    );
    const errorLog = vi.spyOn(console, 'error').mockImplementation(() => {});

    const response = await worker.fetch(
      new Request('https://momentum.example.com/api/canvas/connect', {
        method: 'POST',
        headers: {
          Origin: 'https://momentum.example.com',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ url: canvasFeedUrl }),
      }),
      {
        APP_ORIGIN: 'https://momentum.example.com',
        ALLOWED_CANVAS_HOST: 'canvas.school.edu',
      } as Env,
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({
      error: expect.stringContaining('HTTP 403'),
    });
    expect(errorLog).toHaveBeenCalledTimes(1);
    const logEntry = JSON.parse(errorLog.mock.calls[0][0] as string);
    expect(logEntry).toMatchObject({
      event: 'request_failed',
      path: '/api/canvas/connect',
      provider: 'canvas',
      failure_stage: 'upstream_http',
      upstream_status: 403,
      content_type: 'text/html',
      redirect_count: 0,
    });
    expect(JSON.stringify(logEntry)).not.toContain(canvasFeedUrl);
    expect(JSON.stringify(logEntry)).not.toContain('private-token');
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(fetcher.mock.calls[0][1]?.headers).toMatchObject({
      'User-Agent': 'MomentumCalendarSync/1.0',
    });
  });

  it('keeps invalid Canvas hosts as a 400 validation error', () => {
    try {
      normalizeCalendarIcsUrl(
        'canvas',
        'https://canvas.other.edu/feeds/calendar.ics',
        'canvas.school.edu',
      );
      throw new Error('Expected URL validation to fail.');
    } catch (error) {
      expect(error).toBeInstanceOf(CalendarIcsError);
      expect(error).toMatchObject({
        responseStatus: 400,
        failureStage: 'validation',
      });
    }
  });

  it('keeps redirect host restrictions and identifies rejected redirects', async () => {
    const fetcher = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response(null, {
        status: 302,
        headers: { Location: 'https://other.example.edu/feeds/calendar.ics' },
      }),
    );

    await expect(
      fetchCalendarIcsEvents('canvas', canvasFeedUrl, 'canvas.school.edu'),
    ).rejects.toMatchObject({
      responseStatus: 502,
      upstreamStatus: 302,
      failureStage: 'redirect',
      redirectCount: 1,
    });
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('sends the Canvas User-Agent on the initial request and each allowed redirect', async () => {
    const fetcher = vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(
        new Response(null, {
          status: 302,
          headers: { Location: '/feeds/calendars/redirected.ics' },
        }),
      )
      .mockResolvedValueOnce(
        new Response('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nEND:VCALENDAR\r\n', {
          status: 200,
          headers: { 'Content-Type': 'text/calendar' },
        }),
      );

    await expect(
      fetchCalendarIcsEvents('canvas', canvasFeedUrl, 'canvas.school.edu'),
    ).resolves.toEqual([]);

    expect(fetcher).toHaveBeenCalledTimes(2);
    for (const [, init] of fetcher.mock.calls) {
      expect(init?.headers).toMatchObject({
        'User-Agent': 'MomentumCalendarSync/1.0',
      });
    }
  });

  it('returns a 504 for upstream fetch timeouts', async () => {
    const timeout = new Error('private upstream details');
    timeout.name = 'TimeoutError';
    vi.spyOn(globalThis, 'fetch').mockRejectedValueOnce(timeout);

    await expect(
      fetchCalendarIcsEvents('canvas', canvasFeedUrl, 'canvas.school.edu'),
    ).rejects.toMatchObject({
      responseStatus: 504,
      failureStage: 'timeout',
      upstreamStatus: undefined,
    });
  });

  it('reports successful HTTP responses that do not contain valid ICS', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response('<html>Sign in</html>', {
        status: 200,
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      }),
    );

    await expect(
      fetchCalendarIcsEvents('canvas', canvasFeedUrl, 'canvas.school.edu'),
    ).rejects.toMatchObject({
      responseStatus: 422,
      upstreamStatus: 200,
      contentType: 'text/html',
      failureStage: 'invalid_ics',
      message: expect.stringContaining('HTTP 200'),
    });
  });
});
