import { describe, expect, it } from 'vitest';

import { dateKey, parseDateTime, type IcsDateTime } from '../src/ics_datetime';
import { masterOccurrences } from '../src/ics_calendar_recurrence';

function dateTime(value: string): IcsDateTime {
  const parsed = parseDateTime({ name: 'DTSTART', params: new Map(), value });
  if (!parsed) throw new Error(`Invalid test date-time: ${value}`);
  return parsed;
}

describe('iCalendar recurrence expansion', () => {
  it.each([
    {
      frequency: 'daily',
      start: '20261019T090000Z',
      rule: 'FREQ=DAILY;COUNT=3',
      dates: ['20261019T090000', '20261020T090000', '20261021T090000'],
    },
    {
      frequency: 'weekly',
      start: '20261019T090000Z',
      rule: 'FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4',
      dates: ['20261019T090000', '20261021T090000', '20261026T090000', '20261028T090000'],
    },
    {
      frequency: 'monthly',
      start: '20261015T090000Z',
      rule: 'FREQ=MONTHLY;COUNT=3',
      dates: ['20261015T090000', '20261115T090000', '20261215T090000'],
    },
    {
      frequency: 'yearly',
      start: '20261015T090000Z',
      rule: 'FREQ=YEARLY;COUNT=2',
      dates: ['20261015T090000', '20271015T090000'],
    },
  ])('expands $frequency rules directly', ({ start, rule, dates }) => {
    const occurrences = masterOccurrences(
      dateTime(start),
      rule,
      [],
      new Date('2027-12-31T23:59:59Z'),
    );

    expect(occurrences.isRecurring).toBe(true);
    expect(occurrences.dates.map(dateKey)).toEqual(dates);
  });

  it('merges and sorts explicit recurrence dates without duplicates', () => {
    const start = dateTime('20261019T090000Z');
    const occurrences = masterOccurrences(
      start,
      null,
      [dateTime('20261021T090000Z'), start],
      new Date('2027-12-31T23:59:59Z'),
    );

    expect(occurrences.isRecurring).toBe(true);
    expect(occurrences.dates.map(dateKey)).toEqual([
      '20261019T090000',
      '20261021T090000',
    ]);
  });
});
