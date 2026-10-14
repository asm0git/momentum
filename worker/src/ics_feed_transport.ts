const MAX_FEED_BYTES = 2_000_000;
const MAX_REDIRECTS = 3;
const MAX_ICS_URL_LENGTH = 4096;
const OUTLOOK_ICS_HOSTS = new Set([
  'outlook.live.com',
  'outlook.office365.com',
  'outlook.office.com',
]);
const GOOGLE_ICS_HOSTS = new Set(['calendar.google.com']);

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
    cause?: unknown;
  }) {
    super(options.message, options.cause === undefined ? undefined : { cause: options.cause });
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


export interface FetchedCalendarIcsText {
  text: string;
  upstreamStatus: number;
  contentType?: string;
  redirectCount: number;
}

export function normalizeCalendarIcsUrl(
  provider: CalendarIcsProvider,
  value: string,
  allowedCanvasHost: string,
): URL {
  const input = value.trim();
  if (input.length === 0 || input.length > MAX_ICS_URL_LENGTH) {
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

export async function fetchCalendarIcsText(
  provider: CalendarIcsProvider,
  inputUrl: string,
  allowedCanvasHost: string,
): Promise<FetchedCalendarIcsText> {
  const { response, redirectCount } = await fetchFinalCalendarResponse(
    provider,
    inputUrl,
    allowedCanvasHost,
  );
  return readCalendarResponse(provider, response, redirectCount);
}

async function fetchFinalCalendarResponse(
  provider: CalendarIcsProvider,
  inputUrl: string,
  allowedCanvasHost: string,
): Promise<{ response: Response; redirectCount: number }> {
  let url = normalizeCalendarIcsUrl(provider, inputUrl, allowedCanvasHost);
  let redirectCount = 0;
  while (true) {
    const response = await requestCalendarResponse(provider, url, redirectCount);
    if (!isRedirectResponse(response)) return { response, redirectCount };
    url = resolveRedirectUrl(provider, response, url, allowedCanvasHost, redirectCount);
    redirectCount++;
  }
}

async function requestCalendarResponse(
  provider: CalendarIcsProvider,
  url: URL,
  redirectCount: number,
): Promise<Response> {
  try {
    return await fetch(url, {
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
      redirectCount,
      cause: error,
    });
  }
}

function isRedirectResponse(response: Response): boolean {
  return response.status >= 300 && response.status < 400;
}

function resolveRedirectUrl(
  provider: CalendarIcsProvider,
  response: Response,
  currentUrl: URL,
  allowedCanvasHost: string,
  redirectCount: number,
): URL {
  const location = response.headers.get('Location');
  const upstream = {
    upstreamStatus: response.status,
    contentType: safeContentType(response.headers.get('Content-Type')),
  };
  if (!location || redirectCount >= MAX_REDIRECTS) {
    throw new CalendarIcsError({
      provider,
      failureStage: 'redirect',
      responseStatus: 502,
      ...upstream,
      redirectCount,
      message: `${providerTitle(provider)} returned an unsupported calendar redirect. Copy the published .ics link directly and try again.`,
    });
  }

  try {
    return normalizeCalendarIcsUrl(
      provider,
      new URL(location, currentUrl).toString(),
      allowedCanvasHost,
    );
  } catch (error) {
    throw new CalendarIcsError({
      provider,
      failureStage: 'redirect',
      responseStatus: 502,
      ...upstream,
      redirectCount: redirectCount + 1,
      message: `${providerTitle(provider)} redirected to an unsupported calendar link. Copy the published .ics link directly and try again.`,
      cause: error,
    });
  }
}

function readCalendarResponse(
  provider: CalendarIcsProvider,
  response: Response,
  redirectCount: number,
): Promise<FetchedCalendarIcsText> {
  const contentType = safeContentType(response.headers.get('Content-Type'));
  if (!response.ok) {
    throw new CalendarIcsError({
      provider,
      failureStage: 'upstream_http',
      responseStatus: 502,
      upstreamStatus: response.status,
      contentType,
      redirectCount,
      message: upstreamHttpMessage(provider, response.status),
    });
  }
  const size = Number(response.headers.get('Content-Length') ?? 0);
  if (size > MAX_FEED_BYTES) {
    throw oversizedCalendarError(provider, response, contentType, redirectCount);
  }
  return readCalendarBody(provider, response, contentType, redirectCount);
}

async function readCalendarBody(
  provider: CalendarIcsProvider,
  response: Response,
  contentType: string | undefined,
  redirectCount: number,
): Promise<FetchedCalendarIcsText> {
  const body = await responseBodyText(provider, response, contentType, redirectCount);
  if (new TextEncoder().encode(body).byteLength > MAX_FEED_BYTES) {
    throw oversizedCalendarError(provider, response, contentType, redirectCount);
  }
  return {
    text: body,
    upstreamStatus: response.status,
    contentType,
    redirectCount,
  };
}

async function responseBodyText(
  provider: CalendarIcsProvider,
  response: Response,
  contentType: string | undefined,
  redirectCount: number,
): Promise<string> {
  try {
    return await response.text();
  } catch (error) {
    const timedOut = isTimeoutError(error);
    throw new CalendarIcsError({
      provider,
      failureStage: timedOut ? 'timeout' : 'response',
      responseStatus: timedOut ? 504 : 502,
      upstreamStatus: response.status,
      contentType,
      redirectCount,
      message: timedOut
        ? `${providerTitle(provider)} took too long to return the calendar. Try again.`
        : `Could not read the response from the published ${providerTitle(provider)} calendar. Try again.`,
      cause: error,
    });
  }
}

function oversizedCalendarError(
  provider: CalendarIcsProvider,
  response: Response,
  contentType: string | undefined,
  redirectCount: number,
): CalendarIcsError {
  return new CalendarIcsError({
    provider,
    failureStage: 'size',
    responseStatus: 413,
    upstreamStatus: response.status,
    contentType,
    redirectCount,
    message: 'The published calendar is too large to import.',
  });
}

export function invalidCalendarIcsError(
  provider: CalendarIcsProvider,
  response: FetchedCalendarIcsText,
  cause: unknown,
): CalendarIcsError {
  return new CalendarIcsError({
    provider,
    failureStage: 'invalid_ics',
    responseStatus: 422,
    upstreamStatus: response.upstreamStatus,
    contentType: response.contentType,
    redirectCount: response.redirectCount,
    cause,
    message: `${providerTitle(provider)} returned HTTP ${response.upstreamStatus}, but the response was not a valid iCalendar feed. Check that you copied its published calendar .ics link.`,
  });
}

export function calendarIcsValidationError(
  provider: CalendarIcsProvider,
  message: string,
  cause?: unknown,
): CalendarIcsError {
  return new CalendarIcsError({
    provider,
    failureStage: 'validation',
    responseStatus: 400,
    message,
    cause,
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
