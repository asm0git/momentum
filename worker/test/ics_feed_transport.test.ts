import { afterEach, describe, expect, it, vi } from 'vitest';

import {
  CalendarIcsError,
  fetchCalendarIcsText,
  normalizeCalendarIcsUrl,
} from '../src/ics_feed_transport';

afterEach(() => {
  vi.restoreAllMocks();
});

describe('calendar ICS feed transport', () => {
  it('normalizes published Google links and rejects untrusted hosts', () => {
    expect(
      normalizeCalendarIcsUrl(
        'google',
        'webcal://calendar.google.com/calendar/basic.ics#private-fragment',
        '',
      ).toString(),
    ).toBe('https://calendar.google.com/calendar/basic.ics');

    expect(() =>
      normalizeCalendarIcsUrl(
        'google',
        'https://calendar.attacker.example/feed.ics',
        '',
      ),
    ).toThrowError(CalendarIcsError);
  });

  it('follows an allowed redirect and returns the upstream response metadata', async () => {
    const fetcher = vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(
        new Response(null, {
          status: 302,
          headers: { Location: '/feeds/redirected.ics' },
        }),
      )
      .mockResolvedValueOnce(
        new Response('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nEND:VCALENDAR', {
          status: 200,
          headers: { 'Content-Type': 'text/calendar; charset=utf-8' },
        }),
      );

    await expect(
      fetchCalendarIcsText(
        'canvas',
        'https://canvas.school.instructure.com/feeds/calendar.ics',
        'canvas.school.edu',
      ),
    ).resolves.toEqual({
      text: 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nEND:VCALENDAR',
      upstreamStatus: 200,
      contentType: 'text/calendar',
      redirectCount: 1,
    });

    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(fetcher.mock.calls[0][1]?.redirect).toBe('manual');
    expect(fetcher.mock.calls[1][0]?.toString()).toBe(
      'https://canvas.school.instructure.com/feeds/redirected.ics',
    );
  });

  it('blocks a redirect to an unapproved host', async () => {
    const fetcher = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response(null, {
        status: 302,
        headers: { Location: 'https://attacker.example/collect.ics' },
      }),
    );

    await expect(
      fetchCalendarIcsText(
        'canvas',
        'https://canvas.school.instructure.com/feeds/calendar.ics',
        'canvas.school.edu',
      ),
    ).rejects.toMatchObject({
      name: 'CalendarIcsError',
      responseStatus: 502,
      upstreamStatus: 302,
      failureStage: 'redirect',
      redirectCount: 1,
    });
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('stops after three allowed redirects', async () => {
    const fetcher = vi.spyOn(globalThis, 'fetch').mockImplementation(async () =>
      new Response(null, {
        status: 302,
        headers: { Location: '/feeds/next.ics' },
      }),
    );

    await expect(
      fetchCalendarIcsText(
        'canvas',
        'https://canvas.school.instructure.com/feeds/calendar.ics',
        'canvas.school.edu',
      ),
    ).rejects.toMatchObject({
      name: 'CalendarIcsError',
      failureStage: 'redirect',
      upstreamStatus: 302,
      redirectCount: 3,
    });
    expect(fetcher).toHaveBeenCalledTimes(4);
  });

  it('classifies upstream authorization failures without exposing response content', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response('provider-private-page', {
        status: 403,
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      }),
    );

    await expect(
      fetchCalendarIcsText(
        'google',
        'https://calendar.google.com/calendar/basic.ics',
        '',
      ),
    ).rejects.toMatchObject({
      name: 'CalendarIcsError',
      responseStatus: 502,
      upstreamStatus: 403,
      contentType: 'text/html',
      failureStage: 'upstream_http',
    });
  });
});
