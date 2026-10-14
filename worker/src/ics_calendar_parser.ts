import {
  addMilliseconds,
  dateDifference,
  dateKey,
  makeDateTime,
  parseDateTime,
  serializeDate,
  type IcsDateTime,
  type IcsProperty,
} from './ics_datetime';

const MAX_FEED_EVENTS = 10_000;
const MAX_EXPANDED_EVENTS = 20_000;

export interface IcsCalendarEvent {
  externalId: string;
  title: string;
  start: string;
  end: string;
  allDay: boolean;
  description: string;
  location: string | null;
}

interface IcsComponent {
  properties: Map<string, IcsProperty[]>;
}

export function parseCalendarIcs(source: string): IcsCalendarEvent[] {
  const unfolded = unfoldCalendar(source);
  assertCalendarEnvelope(unfolded);
  const components = parseEventComponents(unfolded);
  const { masters, overrides } = indexRecurringComponents(components);
  const range = eventRange();

  return [
    ...expandMasterOccurrences(masters, overrides, range),
    ...mapDetachedOverrides(masters, overrides, range),
  ];
}

interface RecurringComponents {
  masters: Map<string, IcsComponent>;
  overrides: Map<string, IcsComponent>;
}

interface EventRange {
  start: Date;
  end: Date;
}

function unfoldCalendar(source: string): string {
  return source
    .replace(/^\uFEFF/, '')
    .replace(/\r?\n[ \t]/g, '')
    .replace(/\r/g, '');
}

function assertCalendarEnvelope(source: string): void {
  if (!source.includes('BEGIN:VCALENDAR') || !source.includes('END:VCALENDAR')) {
    throw new Error('The link did not return a valid iCalendar feed.');
  }
}

function parseEventComponents(source: string): IcsComponent[] {
  const components: IcsComponent[] = [];
  let current: IcsComponent | null = null;

  for (const line of source.split('\n')) {
    if (line === 'BEGIN:VEVENT') {
      if (components.length >= MAX_FEED_EVENTS) {
        throw new Error('The published calendar contains too many events.');
      }
      current = { properties: new Map() };
      continue;
    }
    if (line === 'END:VEVENT') {
      if (current) components.push(current);
      current = null;
      continue;
    }
    if (!current) continue;

    const property = parseProperty(line);
    if (!property) continue;
    const properties = current.properties.get(property.name) ?? [];
    properties.push(property);
    current.properties.set(property.name, properties);
  }

  return components;
}

function indexRecurringComponents(components: IcsComponent[]): RecurringComponents {
  const overrides = new Map<string, IcsComponent>();
  const masters = new Map<string, IcsComponent>();

  for (const component of components) {
    const uid = propertyValue(component, 'UID') ?? '';
    if (!uid) continue;

    const recurrence = firstProperty(component, 'RECURRENCE-ID');
    if (!recurrence) {
      masters.set(uid, component);
      continue;
    }

    const date = parseDateTime(recurrence);
    if (date) overrides.set(`${uid}|${dateKey(date)}`, component);
  }

  return { masters, overrides };
}

function eventRange(): EventRange {
  const start = new Date();
  start.setUTCFullYear(start.getUTCFullYear() - 1);
  const end = new Date();
  end.setUTCFullYear(end.getUTCFullYear() + 2);
  return { start, end };
}

function expandMasterOccurrences(
  masters: Map<string, IcsComponent>,
  overrides: Map<string, IcsComponent>,
  range: EventRange,
): IcsCalendarEvent[] {
  const output: IcsCalendarEvent[] = [];
  for (const [uid, master] of masters) {
    output.push(...expandMaster(master, uid, overrides, range));
    if (output.length >= MAX_EXPANDED_EVENTS) {
      throw new Error('The published calendar has too many upcoming events.');
    }
  }
  return output;
}

function expandMaster(
  master: IcsComponent,
  uid: string,
  overrides: Map<string, IcsComponent>,
  range: EventRange,
): IcsCalendarEvent[] {
  const startProperty = firstProperty(master, 'DTSTART');
  if (!startProperty) return [];
  const start = parseDateTime(startProperty);
  if (!start) return [];

  const endProperty = firstProperty(master, 'DTEND');
  const duration = endProperty
    ? dateDifference(start, parseDateTime(endProperty) ?? start)
    : start.allDay
      ? 86_400_000
      : parseDuration(propertyValue(master, 'DURATION')) ?? 0;
  const rule = parseRule(propertyValue(master, 'RRULE'));
  const exclusions = recurringDateSet(master, 'EXDATE');
  const recurrenceDates = recurringDates(master);
  const recurring = rule != null || recurrenceDates.length > 0;
  const candidates = masterCandidates(start, rule, recurrenceDates, range.end);
  const output: IcsCalendarEvent[] = [];

  for (const recurrenceStart of candidates) {
    const recurrenceKey = dateKey(recurrenceStart);
    if (exclusions.has(recurrenceKey)) continue;

    const override = overrides.get(`${uid}|${recurrenceKey}`);
    if (isCancelled(override)) continue;

    const selected = override ?? master;
    const selectedStart = override
      ? parseDateTime(firstProperty(override, 'DTSTART')) ?? recurrenceStart
      : recurrenceStart;
    const selectedEnd = firstProperty(selected, 'DTEND');
    const selectedDuration = selectedEnd
      ? dateDifference(selectedStart, parseDateTime(selectedEnd) ?? selectedStart)
      : duration;
    const end = addMilliseconds(selectedStart, selectedDuration);
    if (end.instant < range.start || selectedStart.instant > range.end) continue;

    output.push(
      toImportedEvent(
        selected,
        uid,
        recurring ? recurrenceStart : null,
        selectedStart,
        end,
      ),
    );
  }

  return output;
}

function recurringDateSet(master: IcsComponent, propertyName: string): Set<string> {
  return new Set(
    (master.properties.get(propertyName) ?? [])
      .flatMap((property) =>
        property.value.split(',').map((value) => parseDateTime({ ...property, value })),
      )
      .filter((value): value is IcsDateTime => value != null)
      .map(dateKey),
  );
}

function recurringDates(master: IcsComponent): IcsDateTime[] {
  return (master.properties.get('RDATE') ?? [])
    .flatMap((property) =>
      property.value.split(',').map((value) =>
        parseDateTime({ ...property, value: value.split('/')[0] }),
      ),
    )
    .filter((value): value is IcsDateTime => value != null);
}

function masterCandidates(
  start: IcsDateTime,
  rule: Map<string, string> | null,
  recurrenceDates: IcsDateTime[],
  rangeEnd: Date,
): IcsDateTime[] {
  const candidates = (rule ? expandRule(start, rule, rangeEnd) : [start])
    .concat(recurrenceDates);
  return [...new Map(candidates.map((candidate) => [dateKey(candidate), candidate])).values()]
    .sort((left, right) => left.instant.getTime() - right.instant.getTime());
}

function mapDetachedOverrides(
  masters: Map<string, IcsComponent>,
  overrides: Map<string, IcsComponent>,
  range: EventRange,
): IcsCalendarEvent[] {
  const output: IcsCalendarEvent[] = [];

  for (const [key, override] of overrides) {
    const [uid] = splitOverrideKey(key);
    if (masters.has(uid) || isCancelled(override)) continue;

    const start = parseDateTime(firstProperty(override, 'DTSTART'));
    if (!start || start.instant < range.start || start.instant > range.end) continue;
    const end = parseDateTime(firstProperty(override, 'DTEND')) ?? start;
    const recurrenceStart = parseDateTime(firstProperty(override, 'RECURRENCE-ID')) ?? start;
    output.push(toImportedEvent(override, uid, recurrenceStart, start, end));
  }

  return output;
}

function isCancelled(component: IcsComponent | undefined): boolean {
  return component != null &&
    propertyValue(component, 'STATUS')?.toUpperCase() === 'CANCELLED';
}

function parseProperty(line: string): IcsProperty | null {
  const separator = line.indexOf(':');
  if (separator <= 0) return null;
  const header = line.slice(0, separator).split(';');
  const name = header.shift()?.toUpperCase();
  if (!name) return null;
  const params = new Map<string, string>();
  for (const parameter of header) {
    const equals = parameter.indexOf('=');
    if (equals > 0) {
      params.set(
        parameter.slice(0, equals).toUpperCase(),
        parameter.slice(equals + 1).replace(/^"|"$/g, ''),
      );
    }
  }
  return { name, params, value: line.slice(separator + 1) };
}

function firstProperty(component: IcsComponent, name: string): IcsProperty | null {
  return component.properties.get(name)?.[0] ?? null;
}

function propertyValue(component: IcsComponent, name: string): string | null {
  return firstProperty(component, name)?.value ?? null;
}

function decodeText(value: string): string {
  return value
    .replace(/\\[nN]/g, '\n')
    .replace(/\\,/g, ',')
    .replace(/\\;/g, ';')
    .replace(/\\\\/g, '\\');
}

function parseRule(value: string | null): Map<string, string> | null {
  if (!value) return null;
  const rule = new Map<string, string>();
  for (const part of value.split(';')) {
    const separator = part.indexOf('=');
    if (separator > 0) {
      rule.set(part.slice(0, separator).toUpperCase(), part.slice(separator + 1));
    }
  }
  return rule.has('FREQ') ? rule : null;
}

function expandRule(
  start: IcsDateTime,
  rule: Map<string, string>,
  rangeEnd: Date,
): IcsDateTime[] {
  const frequency = rule.get('FREQ')?.toUpperCase();
  if (!['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'].includes(frequency ?? '')) {
    return [start];
  }
  const interval = Math.max(1, Number(rule.get('INTERVAL') ?? 1) || 1);
  const countLimit = Math.max(0, Number(rule.get('COUNT') ?? 0) || 0);
  const untilValue = rule.get('UNTIL');
  const until = untilValue
    ? parseDateTime({ name: 'UNTIL', params: new Map(), value: untilValue })?.instant
    : null;
  const weekdays = (rule.get('BYDAY') ?? '').split(',').filter(Boolean);
  const monthDays = (rule.get('BYMONTHDAY') ?? '').split(',').map(Number).filter(Boolean);
  const months = (rule.get('BYMONTH') ?? '').split(',').map(Number).filter(Boolean);
  const fromDay = Date.UTC(start.fields[0], start.fields[1] - 1, start.fields[2]);
  const through = Math.min(rangeEnd.getTime(), until?.getTime() ?? Infinity);
  const output: IcsDateTime[] = [];
  output.push(start);
  let occurrences = 1;
  const maxDays = Math.min(100_000, Math.ceil((through - fromDay) / 86_400_000) + 1);
  for (let offset = 0; offset < maxDays; offset++) {
    const candidateDate = new Date(fromDay + offset * 86_400_000);
    const fields: [number, number, number, number, number, number] = [
      candidateDate.getUTCFullYear(), candidateDate.getUTCMonth() + 1,
      candidateDate.getUTCDate(), start.fields[3], start.fields[4], start.fields[5],
    ];
    const candidate = makeDateTime(fields, start);
    const isStartDate = offset === 0;
    if (candidate.instant < start.instant || isStartDate) continue;
    if (matchesRuleDate(fields, start.fields, frequency!, interval, weekdays, monthDays, months)) {
      occurrences++;
      if (countLimit > 0 && occurrences > countLimit) break;
      if ((!until || candidate.instant <= until) && candidate.instant <= rangeEnd) {
        output.push(candidate);
      }
    }
    if (countLimit > 0 && occurrences >= countLimit) break;
  }
  return output;
}

function matchesRuleDate(
  fields: [number, number, number, number, number, number],
  initial: [number, number, number, number, number, number],
  frequency: string,
  interval: number,
  weekdays: string[],
  monthDays: number[],
  months: number[],
): boolean {
  const [year, month, day] = fields;
  const [startYear, startMonth, startDay] = initial;
  const current = new Date(Date.UTC(year, month - 1, day));
  const initialDate = new Date(Date.UTC(startYear, startMonth - 1, startDay));
  const days = Math.floor((current.getTime() - initialDate.getTime()) / 86_400_000);
  const monthOffset = (year - startYear) * 12 + month - startMonth;
  const hasWeekdayFilter = weekdays.length > 0;
  const hasMonthDayFilter = monthDays.length > 0;
  const isAllowedMonth = months.length === 0 || months.includes(month);
  const matchesWeekdayFilter = hasWeekdayFilter &&
    weekdays.some((item) => matchesByDay(item, current));
  const matchesMonthDayFilter = hasMonthDayFilter && monthDays.some((value) =>
    day === (value > 0 ? value : new Date(Date.UTC(year, month, 0)).getUTCDate() + value + 1),
  );
  if (!isAllowedMonth) return false;

  switch (frequency) {
    case 'DAILY': {
      const matchesInterval = days % interval === 0;
      const matchesWeekday = !hasWeekdayFilter || matchesWeekdayFilter;
      const matchesMonthDay = !hasMonthDayFilter || matchesMonthDayFilter;
      return matchesInterval && matchesWeekday && matchesMonthDay;
    }
    case 'WEEKLY': {
      const weekStart = (date: Date) => {
        const result = new Date(date);
        result.setUTCDate(result.getUTCDate() - ((result.getUTCDay() + 6) % 7));
        return result.getTime();
      };
      const weeks = Math.floor((weekStart(current) - weekStart(initialDate)) / 604_800_000);
      const matchesWeekInterval = weeks >= 0 && weeks % interval === 0;
      const matchesRequestedWeekday = hasWeekdayFilter
        ? matchesWeekdayFilter
        : current.getUTCDay() === initialDate.getUTCDay();
      const matchesRequestedMonthDay = !hasMonthDayFilter || matchesMonthDayFilter;
      return matchesWeekInterval && matchesRequestedWeekday && matchesRequestedMonthDay;
    }
    case 'MONTHLY': {
      const matchesMonthInterval = monthOffset >= 0 && monthOffset % interval === 0;
      if (!matchesMonthInterval) return false;

      const matchesMonthlyDay = hasMonthDayFilter
        ? matchesMonthDayFilter
        : hasWeekdayFilter
          ? matchesWeekdayFilter
          : day === startDay;
      return matchesMonthlyDay;
    }
    case 'YEARLY': {
      const matchesYearInterval = (year - startYear) % interval === 0;
      if (!matchesYearInterval) return false;
      const matchesDefaultMonth = months.length > 0 || month === startMonth;
      if (!matchesDefaultMonth) return false;

      const matchesYearlyDay = hasMonthDayFilter
        ? matchesMonthDayFilter
        : hasWeekdayFilter
          ? matchesWeekdayFilter
          : day === startDay;
      return matchesYearlyDay;
    }
    default:
      return false;
  }
}

function matchesByDay(token: string, date: Date): boolean {
  const match = token.match(/^([+-]?\d+)?(MO|TU|WE|TH|FR|SA|SU)$/i);
  if (!match) return false;
  const weekdays = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];
  if (weekdays[date.getUTCDay()] !== match[2].toUpperCase()) return false;
  if (!match[1]) return true;
  const ordinal = Number(match[1]);
  if (ordinal > 0) return Math.floor((date.getUTCDate() - 1) / 7) + 1 === ordinal;
  const lastDay = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0)).getUTCDate();
  return -Math.floor((lastDay - date.getUTCDate()) / 7) - 1 === ordinal;
}

function parseDuration(value: string | null): number | null {
  if (!value) return null;
  const match = value.match(/^P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/i);
  if (!match) return null;
  return ((Number(match[1] ?? 0) * 7 + Number(match[2] ?? 0)) * 24 +
    Number(match[3] ?? 0)) * 3_600_000 + Number(match[4] ?? 0) * 60_000 +
    Number(match[5] ?? 0) * 1000;
}

function toImportedEvent(
  component: IcsComponent,
  uid: string,
  recurrenceStart: IcsDateTime | null,
  start: IcsDateTime,
  end: IcsDateTime,
): IcsCalendarEvent {
  let adjustedEnd = end;
  if (start.allDay) adjustedEnd = addMilliseconds(end, -86_400_000);
  const identity = recurrenceStart ? dateKey(recurrenceStart) : 'single';
  const location = propertyValue(component, 'LOCATION');
  return {
    externalId: `ics:${uid}:${identity}`,
    title: decodeText(propertyValue(component, 'SUMMARY') ?? 'Untitled event'),
    start: serializeDate(start),
    end: serializeDate(adjustedEnd),
    allDay: start.allDay,
    description: decodeText(propertyValue(component, 'DESCRIPTION') ?? ''),
    location: location == null ? null : decodeText(location),
  };
}

function splitOverrideKey(value: string): [string, string] {
  const separator = value.indexOf('|');
  return [value.slice(0, separator), value.slice(separator + 1)];
}
