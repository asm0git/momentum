export interface CanvasTaskRecord {
  externalId: string;
  title: string;
  due: string;
  description: string;
}

export interface CanvasEventRecord {
  externalId: string;
  title: string;
  start: string;
  end: string;
  allDay: boolean;
  description: string;
  location: string | null;
}

export function normalizeCanvasSiteUrl(
  raw: string,
  allowedHost: string,
): URL {
  let url: URL;
  try {
    url = new URL(raw.trim());
  } catch {
    throw new Error('Enter a valid Canvas site URL.');
  }
  const allowed = allowedHost.trim().toLowerCase();
  if (
    url.protocol !== 'https:' ||
    url.hostname.toLowerCase() !== allowed ||
    url.username ||
    url.password ||
    url.port ||
    url.pathname !== '/' ||
    url.search ||
    url.hash
  ) {
    throw new Error('This Canvas site is not enabled for this Momentum app.');
  }
  return new URL(url.origin);
}

function plainDate(value: string): string {
  return `${value.slice(0, 10)}T00:00:00`;
}

export function mapCanvasAssignment(event: any): CanvasTaskRecord | null {
  const assignment = event.assignment;
  const due = assignment?.due_at ?? event.start_at ?? event.all_day_date;
  if (!due) return null;
  const id = assignment?.id ?? event.id;
  if (id == null) return null;
  const dueValue = event.all_day_date
    ? plainDate(event.all_day_date)
    : new Date(due).toISOString();
  return {
    externalId: `assignment:${event.context_code ?? 'canvas'}:${id}`,
    title: String(assignment?.name ?? event.title ?? 'Canvas assignment'),
    due: dueValue,
    description: String(assignment?.description ?? event.description ?? ''),
  };
}

export function mapCanvasEvent(event: any): CanvasEventRecord | null {
  const id = event.id;
  const allDay = event.all_day === true || Boolean(event.all_day_date);
  const start = event.all_day_date ?? event.start_at;
  if (id == null || !start) return null;
  const end = event.end_at ?? event.start_at ?? event.all_day_date;
  if (!end) return null;
  const startValue = allDay
    ? plainDate(String(event.all_day_date ?? start))
    : new Date(start).toISOString();
  const endValue = allDay
    ? plainDate(String(event.all_day_date ?? end))
    : new Date(end).toISOString();
  const venue = event.location_name ?? event.venue?.name ?? null;
  return {
    externalId: `event:${id}`,
    title: String(event.title ?? 'Canvas event'),
    start: startValue,
    end: endValue,
    allDay,
    description: String(event.description ?? ''),
    location: venue == null ? null : String(venue),
  };
}

export function nextCanvasPage(linkHeader: string | null): string | null {
  if (!linkHeader) return null;
  for (const entry of linkHeader.split(',')) {
    const match = entry.match(/<([^>]+)>\s*;\s*rel="?([^";]+)"?/);
    if (match?.[2].split(/\s+/).includes('next')) return match[1];
  }
  return null;
}

export function splitContextBatches(
  contexts: string[],
  maximum = 10,
): string[][] {
  if (!Number.isInteger(maximum) || maximum < 1) {
    throw new Error('Context batch size must be a positive integer.');
  }
  const batches: string[][] = [];
  for (let index = 0; index < contexts.length; index += maximum) {
    batches.push(contexts.slice(index, index + maximum));
  }
  return batches;
}

export async function fetchCanvasPages<T>(
  siteUrl: URL,
  accessToken: string,
  path: string,
  fetcher: typeof fetch = fetch,
): Promise<T[]> {
  let next: string | null = new URL(path, siteUrl).toString();
  const records: T[] = [];
  let pages = 0;
  while (next) {
    if (++pages > 1000) throw new Error('Canvas returned too many pages.');
    const pageUrl = new URL(next);
    if (
      pageUrl.origin !== siteUrl.origin ||
      !pageUrl.pathname.startsWith('/api/v1/')
    ) {
      throw new Error('Canvas returned an unsafe pagination link.');
    }
    const response = await fetcher(pageUrl, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!response.ok) {
      throw new Error(`Canvas API request failed (${response.status}).`);
    }
    const body = await response.json();
    if (!Array.isArray(body)) {
      throw new Error('Canvas returned an invalid list response.');
    }
    records.push(...(body as T[]));
    next = nextCanvasPage(response.headers.get('Link'));
  }
  return records;
}
