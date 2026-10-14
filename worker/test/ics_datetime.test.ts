import { describe, expect, it } from 'vitest';

import {
  addMilliseconds,
  dateDifference,
  dateKey,
  makeDateTime,
  parseDateTime,
  serializeDate,
  type IcsDateTime,
  type IcsProperty,
} from '../src/ics_datetime';

function property(value: string, params: Record<string, string> = {}): IcsProperty {
  return { name: 'DTSTART', params: new Map(Object.entries(params)), value };
}

describe('iCalendar date and time helpers', () => {
  it('parses UTC date-times and rejects invalid calendar fields', () => {
    expect(parseDateTime(property('20261014T123045Z'))).toMatchObject({
      instant: new Date('2026-10-14T12:30:45.000Z'),
      fields: [2026, 10, 14, 12, 30, 45],
      allDay: false,
      floating: false,
    });
    expect(parseDateTime(property('20260230T090000Z'))).toBeNull();
    expect(parseDateTime(null)).toBeNull();
  });

  it('parses all-day dates and keeps their date-only representation', () => {
    const value = parseDateTime(property('20261014', { VALUE: 'DATE' }));

    expect(value).toMatchObject({ allDay: true, floating: false });
    expect(value && serializeDate(value)).toBe('2026-10-14T00:00:00');
    expect(value && dateKey(value)).toBe('20261014');
  });

  it('converts Windows timezone names and preserves local time over a DST boundary', () => {
    const start = parseDateTime(property('20260307T090000', {
      TZID: 'Eastern Standard Time',
    }));

    expect(start?.instant.toISOString()).toBe('2026-03-07T14:00:00.000Z');
    const nextDay = makeDateTime([2026, 3, 8, 9, 0, 0], start as IcsDateTime);
    expect(nextDay.instant.toISOString()).toBe('2026-03-08T13:00:00.000Z');
    expect(nextDay.fields).toEqual([2026, 3, 8, 9, 0, 0]);
  });

  it('preserves floating wall-clock fields when adding time', () => {
    const start = parseDateTime(property('20261014T230000')) as IcsDateTime;
    const nextDay = addMilliseconds(start, 2 * 60 * 60 * 1000);

    expect(nextDay.fields).toEqual([2026, 10, 15, 1, 0, 0]);
    expect(serializeDate(nextDay)).toBe('2026-10-15T01:00:00');
    expect(dateKey(nextDay)).toBe('20261015T010000');
    expect(dateDifference(start, nextDay)).toBe(2 * 60 * 60 * 1000);
  });

  it('adds elapsed time to zoned values and retains their timezone', () => {
    const start = parseDateTime(property('20261014T090000', {
      TZID: 'Asia/Singapore',
    })) as IcsDateTime;
    const later = addMilliseconds(start, 30 * 60 * 1000);

    expect(later.instant.toISOString()).toBe('2026-10-14T01:30:00.000Z');
    expect(later.fields).toEqual([2026, 10, 14, 9, 30, 0]);
    expect(later.timeZone).toBe('Asia/Singapore');
  });
});
