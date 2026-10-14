// Pure iCalendar date/time parsing and serialization shared by event and recurrence handling.
export interface IcsProperty {
  name: string;
  params: Map<string, string>;
  value: string;
}

type DateTimeFields = [number, number, number, number, number, number];

export interface IcsDateTime {
  instant: Date;
  fields: DateTimeFields;
  allDay: boolean;
  floating: boolean;
  timeZone?: string;
}

interface ParsedDateTimeFields {
  fields: DateTimeFields;
  allDay: boolean;
  isUtc: boolean;
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

export function parseDateTime(property: IcsProperty | null): IcsDateTime | null {
  if (!property) return null;
  const parsed = parseDateTimeFields(property);
  if (!parsed) return null;

  const timeZone = resolveTimeZone(property);
  const { instant, floating } = constructDateTimeInstant(parsed, timeZone);
  return {
    instant,
    fields: parsed.fields,
    allDay: parsed.allDay,
    floating,
    timeZone: floating ? undefined : timeZone,
  };
}

function parseDateTimeFields(property: IcsProperty): ParsedDateTimeFields | null {
  const value = property.value.trim();
  const allDay = property.params.get('VALUE')?.toUpperCase() === 'DATE' ||
    /^\d{8}$/.test(value);
  const match = value.match(
    /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/i,
  );
  if (!match) return null;
  const fields: DateTimeFields = [
    Number(match[1]),
    Number(match[2]),
    Number(match[3]),
    Number(match[4] ?? 0),
    Number(match[5] ?? 0),
    Number(match[6] ?? 0),
  ];
  if (!isValidFields(fields)) return null;

  return {
    fields,
    allDay,
    isUtc: match[7]?.toUpperCase() === 'Z',
  };
}

function resolveTimeZone(property: IcsProperty): string | undefined {
  const rawZone = property.params.get('TZID');
  if (!rawZone) return undefined;
  return windowsTimeZones[rawZone.toLowerCase()] ?? rawZone;
}

function constructDateTimeInstant(
  parsed: ParsedDateTimeFields,
  timeZone: string | undefined,
): { instant: Date; floating: boolean } {
  if (parsed.isUtc) return { instant: utcDate(parsed.fields), floating: false };
  if (timeZone && isSupportedTimeZone(timeZone)) {
    return { instant: zonedDate(parsed.fields, timeZone), floating: false };
  }
  return {
    instant: utcDate(parsed.fields),
    floating: !parsed.allDay,
  };
}

function utcDate(fields: DateTimeFields): Date {
  return new Date(Date.UTC(
    fields[0], fields[1] - 1, fields[2], fields[3], fields[4], fields[5],
  ));
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
    fields[3] >= 0 && fields[3] <= 23 &&
    fields[4] >= 0 && fields[4] <= 59 &&
    fields[5] >= 0 && fields[5] <= 60;
}

function zonedDate(
  fields: DateTimeFields,
  timeZone: string,
): Date {
  const wallClockTime = utcDate(fields).getTime();
  let guess = wallClockTime;
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
      guess += wallClockTime - represented;
    }
  } catch {
    // Preserve the feed's wall-clock time when its timezone is not recognized.
  }
  return new Date(guess);
}

export function makeDateTime(
  fields: DateTimeFields,
  template: IcsDateTime,
): IcsDateTime {
  const [year, month, day, hour, minute, second] = fields;
  const instant = template.timeZone
    ? zonedDate(fields, template.timeZone)
    : new Date(Date.UTC(year, month - 1, day, hour, minute, second));
  return {
    instant,
    fields,
    allDay: template.allDay,
    floating: template.floating,
    timeZone: template.timeZone,
  };
}

export function dateDifference(start: IcsDateTime, end: IcsDateTime): number {
  return end.instant.getTime() - start.instant.getTime();
}

export function addMilliseconds(value: IcsDateTime, milliseconds: number): IcsDateTime {
  if (value.allDay && value.floating) {
    const [year, month, date] = value.fields;
    const day = new Date(Date.UTC(year, month - 1, date));
    const daysToAdd = Math.round(milliseconds / 86_400_000);
    day.setUTCDate(day.getUTCDate() + daysToAdd);
    return makeDateTime([
      day.getUTCFullYear(),
      day.getUTCMonth() + 1,
      day.getUTCDate(),
      0,
      0,
      0,
    ], value);
  }
  const instant = new Date(value.instant.getTime() + milliseconds);
  let fields: DateTimeFields;
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
  return {
    instant,
    fields,
    allDay: value.allDay,
    floating: value.floating,
    timeZone: value.timeZone,
  };
}

export function serializeDate(value: IcsDateTime): string {
  const [year, month, day, hour, minute, second] = value.fields;
  const datePart = `${pad(year, 4)}-${pad(month)}-${pad(day)}`;
  if (value.allDay) return `${datePart}T00:00:00`;
  if (!value.floating) return value.instant.toISOString();

  const timePart = `${pad(hour)}:${pad(minute)}:${pad(second)}`;
  return `${datePart}T${timePart}`;
}

export function dateKey(value: IcsDateTime): string {
  const [year, month, day, hour, minute, second] = value.fields;
  const datePart = `${pad(year, 4)}${pad(month)}${pad(day)}`;
  if (value.allDay) return datePart;

  const timePart = `${pad(hour)}${pad(minute)}${pad(second)}`;
  return `${datePart}T${timePart}`;
}

export function pad(value: number, width = 2): string {
  return String(value).padStart(width, '0');
}
