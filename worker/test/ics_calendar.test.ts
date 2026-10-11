import { afterEach, describe, expect, it, vi } from 'vitest';

import worker, { type Env } from '../src/index';
import {
  CalendarIcsError,
  fetchCalendarIcsEvents,
  normalizeCalendarIcsUrl,
} from '../src/ics_calendar';

const canvasFeedUrl =
  'https://canvas.school.instructure.com/feeds/calendars/user_123.ics?verifier=private-token';

afterEach(() => {
  vi.restoreAllMocks();
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
