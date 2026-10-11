const MAX_FEED_BYTES = 2_000_000;
const MAX_FEED_EVENTS = 10_000;
const MAX_EXPANDED_EVENTS = 20_000;
const OUTLOOK_ICS_HOSTS = new Set([
  'outlook.live.com',
  'outlook.office365.com',
  'outlook.office.com',
]);
const GOOGLE_ICS_HOSTS = new Set(['calendar.google.com']);

export interface IcsCalendarEvent {
  externalId: string;
  title: string;
  start: string;
  end: string;
  allDay: boolean;
  description: string;
  location: string | null;
}

interface IcsProperty {
  name: string;
  params: Map<string, string>;
  value: string;
}

interface IcsDateTime {
  instant: Date;
  fields: [number, number, number, number, number, number];
  allDay: boolean;
  floating: boolean;
  timeZone?: string;
}

interface IcsComponent {
  properties: Map<string, IcsProperty[]>;
}

const windowsTimeZones: Record<string, string> = {
  'eastern standard time': 'America/New_York',
  'central standard time': 'America/Chicago',
  'mountain standard time': 'America/Denver',
  'pacific standard time': 'America/Los_Angeles',
  'alaskan standard time': 'America/Anchorage',
  'hawaiian standard time': 'Pacific/Honolulu',
  'gmt standard time': 'Europe/London',
  'greenwich standard time': 'Atlantic/Reykjavik',
  'w. europe standard time': 'Europe/Berlin',
  'central europe standard time': 'Europe/Budapest',
  'romance standard time': 'Europe/Paris',
  'e. europe standard time': 'Europe/Chisinau',
  'fle standard time': 'Europe/Kyiv',
  'turkey standard time': 'Europe/Istanbul',
  'russian standard time': 'Europe/Moscow',
  'india standard time': 'Asia/Kolkata',
  'china standard time': 'Asia/Shanghai',
  'singapore standard time': 'Asia/Singapore',
  'tokyo standard time': 'Asia/Tokyo',
  'korea standard time': 'Asia/Seoul',
  'aus eastern standard time': 'Australia/Sydney',
  'australian eastern standard time': 'Australia/Sydney',
  'new zealand standard time': 'Pacific/Auckland',
};

export type CalendarIcsProvider = 'canvas' | 'google' | 'outlook';

export type CalendarIcsFailureStage =
  | 'validation'
  | 'fetch'
  | 'timeout'
  | 'upstream_http'
  | 'redirect'
  | 'response'
  | 'invalid_ics'
  | 'size';

export class CalendarIcsError extends Error {
  readonly provider: CalendarIcsProvider;
  readonly failureStage: CalendarIcsFailureStage;
  readonly responseStatus: number;
  readonly upstreamStatus?: number;
  readonly contentType?: string;
  readonly redirectCount: number;

  constructor(options: {
    provider: CalendarIcsProvider;
    failureStage: CalendarIcsFailureStage;
    responseStatus: number;
    message: string;
    upstreamStatus?: number;
    contentType?: string;
    redirectCount?: number;
  }) {
    super(options.message);
    this.name = 'CalendarIcsError';
    this.provider = options.provider;
    this.failureStage = options.failureStage;
    this.responseStatus = options.responseStatus;
    this.upstreamStatus = options.upstreamStatus;
    this.contentType = options.contentType;
    this.redirectCount = options.redirectCount ?? 0;
  }

  diagnostics(): Record<string, string | number> {
    return {
      provider: this.provider,
      failure_stage: this.failureStage,
      ...(this.upstreamStatus === undefined
        ? {}
        : { upstream_status: this.upstreamStatus }),
      ...(this.contentType === undefined
        ? {}
        : { content_type: this.contentType }),
      redirect_count: this.redirectCount,
    };
  }
}

export function normalizeCalendarIcsUrl(
  provider: CalendarIcsProvider,
  value: string,
  allowedCanvasHost: string,
): URL {
  const input = value.trim();
  if (input.length === 0 || input.length > 4096) {
    throw calendarIcsValidationError(provider, `Paste a valid ${providerTitle(provider)} .ics link.`);
  }
  let url: URL;
  try {
    url = new URL(input.replace(/^webcal:/i, 'https:'));
  } catch {
    throw calendarIcsValidationError(provider, `Paste a valid ${providerTitle(provider)} .ics link.`);
  }
  const host = url.hostname.toLowerCase();
  const configuredCanvasHost = allowedCanvasHost.trim().toLowerCase();
  const providerHostIsValid = provider === 'outlook'
    ? OUTLOOK_ICS_HOSTS.has(host)
    : provider === 'google'
      ? GOOGLE_ICS_HOSTS.has(host)
      : host.endsWith('.instructure.com') || host === configuredCanvasHost;
  if (
    url.protocol !== 'https:' ||
    !providerHostIsValid ||
    url.username !== '' ||
    url.password !== '' ||
    url.port !== '' ||
    !url.pathname.toLowerCase().endsWith('.ics')
  ) {
    throw calendarIcsValidationError(
      provider,
      `Use the HTTPS .ics link published by ${providerTitle(provider)}.`,
    );
  }
  url.hash = '';
  return url;
}

export async function fetchCalendarIcsEvents(
  provider: CalendarIcsProvider,
  inputUrl: string,
  allowedCanvasHost: string,
): Promise<IcsCalendarEvent[]> {
  let url = normalizeCalendarIcsUrl(provider, inputUrl, allowedCanvasHost);
  let response: Response | null = null;
  let redirectsFollowed = 0;
  for (;;) {
    try {
      response = await fetch(url, {
        headers: {
          Accept: 'text/calendar, text/plain;q=0.9, */*;q=0.1',
          ...(provider === 'canvas'
            ? { 'User-Agent': 'MomentumCalendarSync/1.0' }
            : {}),
        },
        redirect: 'manual',
        signal: AbortSignal.timeout(10_000),
      });
    } catch (error) {
      const timedOut = isTimeoutError(error);
      throw new CalendarIcsError({
        provider,
        failureStage: timedOut ? 'timeout' : 'fetch',
        responseStatus: timedOut ? 504 : 502,
        message: timedOut
          ? `${providerTitle(provider)} took too long to return the calendar. Try again.`
          : `Could not reach the published ${providerTitle(provider)} calendar. Try again.`,
        redirectCount: redirectsFollowed,
      });
    }
    if (response.status < 300 || response.status >= 400) break;
    const location = response.headers.get('Location');
    if (!location || redirectsFollowed >= 3) {
      throw new CalendarIcsError({
        provider,
        failureStage: 'redirect',
        responseStatus: 502,
        upstreamStatus: response.status,
        contentType: safeContentType(response.headers.get('Content-Type')),
        redirectCount: redirectsFollowed,
        message: `${providerTitle(provider)} returned an unsupported calendar redirect. Copy the published .ics link directly and try again.`,
      });
    }
    redirectsFollowed++;
    try {
      url = normalizeCalendarIcsUrl(
        provider,
        new URL(location, url).toString(),
        allowedCanvasHost,
      );
    } catch {
      throw new CalendarIcsError({
        provider,
        failureStage: 'redirect',
        responseStatus: 502,
        upstreamStatus: response.status,
        contentType: safeContentType(response.headers.get('Content-Type')),
        redirectCount: redirectsFollowed,
        message: `${providerTitle(provider)} redirected to an unsupported calendar link. Copy the published .ics link directly and try again.`,
      });
    }
  }
  if (!response) {
    throw new CalendarIcsError({
      provider,
      failureStage: 'fetch',
      responseStatus: 502,
      redirectCount: redirectsFollowed,
      message: `Could not reach the published ${providerTitle(provider)} calendar. Try again.`,
    });
  }
  const contentType = safeContentType(response.headers.get('Content-Type'));
  if (!response.ok) {
    throw new CalendarIcsError({
      provider,
      failureStage: 'upstream_http',
      responseStatus: 502,
      upstreamStatus: response.status,
      contentType,
      redirectCount: redirectsFollowed,
      message: upstreamHttpMessage(provider, response.status),
    });
  }
  const size = Number(response.headers.get('Content-Length') ?? 0);
  if (size > MAX_FEED_BYTES) {
    throw new CalendarIcsError({
      provider,
      failureStage: 'size',
      responseStatus: 413,
      upstreamStatus: response.status,
      contentType,
      redirectCount: redirectsFollowed,
      message: 'The published calendar is too large to import.',
    });
  }
  let body: string;
  try {
    body = await response.text();
  } catch (error) {
    const timedOut = isTimeoutError(error);
    throw new CalendarIcsError({
      provider,
      failureStage: timedOut ? 'timeout' : 'response',
      responseStatus: timedOut ? 504 : 502,
      upstreamStatus: response.status,
      contentType,
      redirectCount: redirectsFollowed,
      message: timedOut
        ? `${providerTitle(provider)} took too long to return the calendar. Try again.`
        : `Could not read the response from the published ${providerTitle(provider)} calendar. Try again.`,
    });
  }
  if (new TextEncoder().encode(body).byteLength > MAX_FEED_BYTES) {
    throw new CalendarIcsError({
      provider,
      failureStage: 'size',
      responseStatus: 413,
      upstreamStatus: response.status,
      contentType,
      redirectCount: redirectsFollowed,
      message: 'The published calendar is too large to import.',
    });
  }
  try {
    return parseCalendarIcs(body);
  } catch {
    throw new CalendarIcsError({
      provider,
      failureStage: 'invalid_ics',
      responseStatus: 422,
      upstreamStatus: response.status,
      contentType,
      redirectCount: redirectsFollowed,
      message: `${providerTitle(provider)} returned HTTP ${response.status}, but the response was not a valid iCalendar feed. Check that you copied its published calendar .ics link.`,
    });
  }
}

export function calendarIcsValidationError(
  provider: CalendarIcsProvider,
  message: string,
): CalendarIcsError {
  return new CalendarIcsError({
    provider,
    failureStage: 'validation',
    responseStatus: 400,
    message,
  });
}

function isTimeoutError(error: unknown): boolean {
  return error instanceof Error &&
    (error.name === 'TimeoutError' || error.name === 'AbortError');
}

function safeContentType(value: string | null): string | undefined {
  const mediaType = value?.split(';', 1)[0]?.trim().toLowerCase();
  return mediaType && /^[a-z0-9!#$&^_.+-]+\/[a-z0-9!#$&^_.+-]+$/.test(mediaType)
    ? mediaType
    : undefined;
}

function upstreamHttpMessage(
  provider: CalendarIcsProvider,
  status: number,
): string {
  const title = providerTitle(provider);
  if (status === 401 || status === 403) {
    const accessHint = provider === 'canvas'
      ? 'Canvas or your network may be blocking server requests.'
      : 'The provider may be blocking server requests.';
    return `${title} denied the calendar request (HTTP ${status}). Confirm the feed is still published. If it downloads in your browser, ${accessHint}`;
  }
  if (status === 404) {
    return `${title} returned HTTP 404. Copy a fresh published calendar .ics link and try again.`;
  }
  if (status === 429) {
    return `${title} rate-limited the calendar request (HTTP 429). Wait a minute, then try again.`;
  }
  if (status >= 500) {
    return `${title} is temporarily unavailable (HTTP ${status}). Try again later.`;
  }
  return `Could not read the published ${title} calendar (HTTP ${status}). Check the link and try again.`;
}

function providerTitle(provider: CalendarIcsProvider): string {
  return provider === 'google'
    ? 'Google Calendar'
    : provider === 'outlook'
      ? 'Outlook'
      : 'Canvas';
}

export function parseCalendarIcs(source: string): IcsCalendarEvent[] {
  const unfolded = source
    .replace(/^\uFEFF/, '')
    .replace(/\r?\n[ \t]/g, '')
    .replace(/\r/g, '');
  if (
    !unfolded.includes('BEGIN:VCALENDAR') ||
    !unfolded.includes('END:VCALENDAR')
  ) {
    throw new Error('The link did not return a valid iCalendar feed.');
  }

  const components: IcsComponent[] = [];
  let current: IcsComponent | null = null;
  for (const line of unfolded.split('\n')) {
    if (line === 'BEGIN:VEVENT') {
      if (components.length >= MAX_FEED_EVENTS) {
        throw new Error('The published calendar contains too many events.');
      }
      current = { properties: new Map() };
    } else if (line === 'END:VEVENT') {
      if (current) components.push(current);
      current = null;
    } else if (current) {
      const property = parseProperty(line);
      if (property) {
        const properties = current.properties.get(property.name) ?? [];
        properties.push(property);
        current.properties.set(property.name, properties);
      }
    }
  }

  const overrides = new Map<string, IcsComponent>();
  const masters = new Map<string, IcsComponent>();
  for (const component of components) {
    const uid = propertyValue(component, 'UID') ?? '';
    if (!uid) continue;
    const recurrence = firstProperty(component, 'RECURRENCE-ID');
    if (recurrence) {
      const date = parseDateTime(recurrence);
      if (date) overrides.set(`${uid}|${dateKey(date)}`, component);
    } else {
      masters.set(uid, component);
    }
  }

  const rangeStart = new Date();
  rangeStart.setUTCFullYear(rangeStart.getUTCFullYear() - 1);
  const rangeEnd = new Date();
  rangeEnd.setUTCFullYear(rangeEnd.getUTCFullYear() + 2);
  const output: IcsCalendarEvent[] = [];

  for (const [uid, master] of masters) {
    const startProperty = firstProperty(master, 'DTSTART');
    if (!startProperty) continue;
    const start = parseDateTime(startProperty);
    if (!start) continue;
    const endProperty = firstProperty(master, 'DTEND');
    const duration = endProperty
      ? dateDifference(start, parseDateTime(endProperty) ?? start)
      : start.allDay
        ? 86_400_000
        : parseDuration(propertyValue(master, 'DURATION')) ?? 0;
    const rule = parseRule(propertyValue(master, 'RRULE'));
    const exclusions = new Set(
      (master.properties.get('EXDATE') ?? [])
        .flatMap((property) =>
          property.value.split(',').map((value) =>
            parseDateTime({ ...property, value }),
          ),
        )
        .filter((value): value is IcsDateTime => value != null)
        .map(dateKey),
    );
    const rdates = (master.properties.get('RDATE') ?? [])
      .flatMap((property) =>
        property.value.split(',').map((value) =>
          parseDateTime({ ...property, value: value.split('/')[0] }),
        ),
      )
      .filter((value): value is IcsDateTime => value != null);
    const recurring = rule != null || rdates.length > 0;
    const candidateMap = new Map(
      (rule ? expandRule(start, rule, rangeEnd) : [start])
        .concat(rdates)
        .map((candidate) => [dateKey(candidate), candidate]),
    );
    const candidates = [...candidateMap.values()].sort(
      (left, right) => left.instant.getTime() - right.instant.getTime(),
    );
    for (const recurrenceStart of candidates) {
      const recurrenceKey = dateKey(recurrenceStart);
      if (exclusions.has(recurrenceKey)) continue;
      const override = overrides.get(`${uid}|${recurrenceKey}`);
      if (override && propertyValue(override, 'STATUS')?.toUpperCase() === 'CANCELLED') {
        continue;
      }
      const selected = override ?? master;
      const selectedStart = override
        ? parseDateTime(firstProperty(override, 'DTSTART')!) ?? recurrenceStart
        : recurrenceStart;
      const selectedEndProperty = firstProperty(selected, 'DTEND');
      const selectedDuration = selectedEndProperty
        ? dateDifference(
            selectedStart,
            parseDateTime(selectedEndProperty) ?? selectedStart,
          )
        : override
          ? duration
          : duration;
      const end = addMilliseconds(selectedStart, selectedDuration);
      if (end.instant < rangeStart || selectedStart.instant > rangeEnd) continue;
      output.push(
        toImportedEvent(
          selected,
          uid,
          recurring ? recurrenceStart : null,
          selectedStart,
          end,
        ),
      );
      if (output.length >= MAX_EXPANDED_EVENTS) {
        throw new Error('The published calendar has too many upcoming events.');
      }
    }
  }

  // A feed may contain a detached exception without a matching master.
  for (const [key, override] of overrides) {
    const [uid, recurrenceKey] = splitOverrideKey(key);
    if (masters.has(uid) || propertyValue(override, 'STATUS')?.toUpperCase() === 'CANCELLED') {
      continue;
    }
    const start = parseDateTime(firstProperty(override, 'DTSTART')!);
    if (!start || start.instant < rangeStart || start.instant > rangeEnd) continue;
    const end = parseDateTime(firstProperty(override, 'DTEND')!) ?? start;
    output.push(toImportedEvent(override, uid, parseDateTime({ name: 'RECURRENCE-ID', params: new Map(), value: recurrenceKey }) ?? start, start, end));
  }
  return output;
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

function parseDateTime(property: IcsProperty | null): IcsDateTime | null {
  if (!property) return null;
  const value = property.value.trim();
  const dateOnly = property.params.get('VALUE')?.toUpperCase() === 'DATE' ||
    /^\d{8}$/.test(value);
  const match = value.match(
    /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/i,
  );
  if (!match) return null;
  const fields: [number, number, number, number, number, number] = [
    Number(match[1]),
    Number(match[2]),
    Number(match[3]),
    Number(match[4] ?? 0),
    Number(match[5] ?? 0),
    Number(match[6] ?? 0),
  ];
  if (!isValidFields(fields)) return null;
  const utcValue = Date.UTC(
    fields[0], fields[1] - 1, fields[2], fields[3], fields[4], fields[5],
  );
  const rawZone = property.params.get('TZID');
  const timeZone = rawZone
    ? windowsTimeZones[rawZone.toLowerCase()] ?? rawZone
    : undefined;
  const isUtc = match[7]?.toUpperCase() === 'Z';
  let instant: Date;
  let floating: boolean;
  if (isUtc) {
    instant = new Date(utcValue);
    floating = false;
  } else if (timeZone && isSupportedTimeZone(timeZone)) {
    instant = zonedDate(fields, timeZone);
    floating = false;
  } else {
    instant = new Date(utcValue);
    floating = !dateOnly;
  }
  return {
    instant,
    fields,
    allDay: dateOnly,
    floating,
    timeZone: floating ? undefined : timeZone,
  };
}

function isSupportedTimeZone(timeZone: string): boolean {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone }).format(new Date());
    return true;
  } catch {
    return false;
  }
}

function isValidFields(fields: number[]): boolean {
  const date = new Date(Date.UTC(fields[0], fields[1] - 1, fields[2]));
  return date.getUTCFullYear() === fields[0] &&
    date.getUTCMonth() + 1 === fields[1] && date.getUTCDate() === fields[2] &&
    fields[3] <= 23 && fields[4] <= 59 && fields[5] <= 60;
}

function zonedDate(
  fields: [number, number, number, number, number, number],
  timeZone: string,
): Date {
  let guess = Date.UTC(
    fields[0], fields[1] - 1, fields[2], fields[3], fields[4], fields[5],
  );
  try {
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone,
      year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit',
      hourCycle: 'h23',
    });
    for (let attempt = 0; attempt < 3; attempt++) {
      const parts = Object.fromEntries(
        formatter.formatToParts(new Date(guess)).map((part) => [part.type, part.value]),
      );
      const represented = Date.UTC(
        Number(parts.year), Number(parts.month) - 1, Number(parts.day),
        Number(parts.hour), Number(parts.minute), Number(parts.second),
      );
      guess += Date.UTC(
        fields[0], fields[1] - 1, fields[2], fields[3], fields[4], fields[5],
      ) - represented;
    }
  } catch {
    // Preserve the feed's wall-clock time when its timezone is not recognized.
  }
  return new Date(guess);
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
  const byDay = weekdays.length > 0 && weekdays.some((item) => matchesByDay(item, current));
  const byMonthDay = monthDays.length > 0 && monthDays.some((value) =>
    day === (value > 0 ? value : new Date(Date.UTC(year, month, 0)).getUTCDate() + value + 1),
  );
  if (months.length > 0 && !months.includes(month)) return false;
  switch (frequency) {
    case 'DAILY':
      return days % interval === 0 &&
        (weekdays.length === 0 || byDay) &&
        (monthDays.length === 0 || byMonthDay);
    case 'WEEKLY': {
      const weekStart = (date: Date) => {
        const result = new Date(date);
        result.setUTCDate(result.getUTCDate() - ((result.getUTCDay() + 6) % 7));
        return result.getTime();
      };
      const weeks = Math.floor((weekStart(current) - weekStart(initialDate)) / 604_800_000);
      const allowedDays = weekdays.length > 0
        ? weekdays.some((item) => matchesByDay(item, current))
        : current.getUTCDay() === initialDate.getUTCDay();
      return weeks >= 0 && weeks % interval === 0 && allowedDays &&
        (monthDays.length === 0 || byMonthDay);
    }
    case 'MONTHLY': {
      if (monthOffset < 0 || monthOffset % interval !== 0) return false;
      const dayMatches = monthDays.length > 0
        ? byMonthDay
        : weekdays.length > 0
          ? byDay
          : day === startDay;
      return dayMatches && (!months.length || months.includes(month));
    }
    case 'YEARLY': {
      if ((year - startYear) % interval !== 0) return false;
      if (months.length === 0 && month !== startMonth) return false;
      const dayMatches = monthDays.length > 0
        ? byMonthDay
        : weekdays.length > 0
          ? byDay
          : day === startDay;
      return dayMatches;
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

function makeDateTime(
  fields: [number, number, number, number, number, number],
  template: IcsDateTime,
): IcsDateTime {
  const instant = template.timeZone
    ? zonedDate(fields, template.timeZone)
    : new Date(Date.UTC(fields[0], fields[1] - 1, fields[2], fields[3], fields[4], fields[5]));
  return { instant, fields, allDay: template.allDay, floating: template.floating, timeZone: template.timeZone };
}

function dateDifference(start: IcsDateTime, end: IcsDateTime): number {
  return end.instant.getTime() - start.instant.getTime();
}

function addMilliseconds(value: IcsDateTime, milliseconds: number): IcsDateTime {
  if (value.allDay && value.floating) {
    const day = new Date(Date.UTC(value.fields[0], value.fields[1] - 1, value.fields[2]));
    day.setUTCDate(day.getUTCDate() + Math.round(milliseconds / 86_400_000));
    return makeDateTime([
      day.getUTCFullYear(), day.getUTCMonth() + 1, day.getUTCDate(), 0, 0, 0,
    ], value);
  }
  const instant = new Date(value.instant.getTime() + milliseconds);
  let fields: [number, number, number, number, number, number];
  if (value.floating) {
    fields = [
      instant.getUTCFullYear(),
      instant.getUTCMonth() + 1,
      instant.getUTCDate(),
      instant.getUTCHours(),
      instant.getUTCMinutes(),
      instant.getUTCSeconds(),
    ];
  } else {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: value.timeZone ?? 'UTC',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(instant);
    const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
    fields = [
      Number(values.year),
      Number(values.month),
      Number(values.day),
      Number(values.hour),
      Number(values.minute),
      Number(values.second),
    ];
  }
  return { instant, fields, allDay: value.allDay, floating: value.floating, timeZone: value.timeZone };
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
  return {
    externalId: `ics:${uid}:${identity}`,
    title: decodeText(propertyValue(component, 'SUMMARY') ?? 'Untitled event'),
    start: serializeDate(start),
    end: serializeDate(adjustedEnd),
    allDay: start.allDay,
    description: decodeText(propertyValue(component, 'DESCRIPTION') ?? ''),
    location: propertyValue(component, 'LOCATION') == null
      ? null
      : decodeText(propertyValue(component, 'LOCATION')!),
  };
}

function serializeDate(value: IcsDateTime): string {
  if (value.allDay) return `${pad(value.fields[0], 4)}-${pad(value.fields[1])}-${pad(value.fields[2])}T00:00:00`;
  if (value.floating) {
    return `${pad(value.fields[0], 4)}-${pad(value.fields[1])}-${pad(value.fields[2])}T${pad(value.fields[3])}:${pad(value.fields[4])}:${pad(value.fields[5])}`;
  }
  return value.instant.toISOString();
}

function dateKey(value: IcsDateTime): string {
  return value.allDay
    ? `${pad(value.fields[0], 4)}${pad(value.fields[1])}${pad(value.fields[2])}`
    : `${pad(value.fields[0], 4)}${pad(value.fields[1])}${pad(value.fields[2])}T${pad(value.fields[3])}${pad(value.fields[4])}${pad(value.fields[5])}`;
}

function splitOverrideKey(value: string): [string, string] {
  const separator = value.indexOf('|');
  return [value.slice(0, separator), value.slice(separator + 1)];
}

function pad(value: number, width = 2): string {
  return String(value).padStart(width, '0');
}
