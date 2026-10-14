import {
  calendarIcsValidationError,
  fetchCalendarIcsEvents,
  normalizeCalendarIcsUrl,
  type CalendarIcsProvider,
} from './ics_calendar';
import type { Env } from './env';
import { json } from './http';
import {
  activeSessionId,
  getOrCreateSession,
} from './session';
import { decrypt, encrypt, fingerprint } from './security';

interface CalendarIcsFeedRow {
  session_id: string;
  provider: CalendarIcsProvider;
  remote_user_id: string;
  encrypted_feed_url: string;
  last_sync_time: string | null;
}

export function handleProviderRequest(
  request: Request,
  env: Env,
  provider: CalendarIcsProvider,
  endpoint: string,
): Response | Promise<Response> {
  switch (`${request.method} ${endpoint}`) {
    case 'GET oauth/start':
      return json({ error: `Connect ${provider} with a published .ics link.` }, 410);
    case 'GET oauth/callback':
      return json({ error: 'Calendar OAuth is no longer used.' }, 410);
    case 'GET status':
      return providerStatus(request, env, provider);
    case 'POST connect':
      return connectCalendarIcsFeed(request, env, provider);
    case 'POST sync':
      return syncCalendarIcsFeed(request, env, provider);
    case 'POST disconnect':
      return disconnectProvider(request, env, provider);
    default:
      return json({ error: 'Not found.' }, 404);
  }
}

async function providerStatus(
  request: Request,
  env: Env,
  provider: CalendarIcsProvider,
): Promise<Response> {
  const feed = await calendarIcsFeedForRequest(request, env, provider);
  if (!feed) return json({ connected: false });
  return json({
    connected: true,
    providerUrl: `${provider}-published-ics`,
    accountName: publishedCalendarName(provider),
    remoteUserId: feed.remote_user_id,
    lastSyncTime: feed.last_sync_time,
  });
}

async function connectCalendarIcsFeed(
  request: Request,
  env: Env,
  provider: CalendarIcsProvider,
): Promise<Response> {
  const feedUrl = await validatedPublishedFeedUrl(
    request,
    provider,
    env.ALLOWED_CANVAS_HOST,
  );

  const { sessionId, cookie } = await getOrCreateSession(request, env.DB);
  await env.DB.prepare(`
    INSERT INTO calendar_ics_feeds
      (session_id, provider, remote_user_id, encrypted_feed_url, last_sync_time)
    VALUES (?, ?, ?, ?, NULL)
    ON CONFLICT(session_id, provider) DO UPDATE SET
      remote_user_id = excluded.remote_user_id,
      encrypted_feed_url = excluded.encrypted_feed_url,
      last_sync_time = NULL
  `)
    .bind(
      sessionId,
      provider,
      await fingerprint(feedUrl),
      await encrypt(feedUrl, env.TOKEN_ENCRYPTION_KEY),
    )
    .run();

  return json({ connected: true }, 200, { 'Set-Cookie': cookie });
}

async function validatedPublishedFeedUrl(
  request: Request,
  provider: CalendarIcsProvider,
  allowedCanvasHost: string,
): Promise<string> {
  let body: unknown;
  try {
    body = await request.json();
  } catch (cause) {
    throw calendarIcsValidationError(
      provider,
      `Paste a valid published ${provider} .ics link.`,
      cause,
    );
  }
  if (!isRecord(body) || typeof body.url !== 'string') {
    throw calendarIcsValidationError(
      provider,
      `Paste a valid published ${provider} .ics link.`,
    );
  }

  const feedUrl = normalizeCalendarIcsUrl(
    provider,
    body.url,
    allowedCanvasHost,
  ).toString();
  // Validate before saving so a typo never replaces a working feed.
  await fetchCalendarIcsEvents(provider, feedUrl, allowedCanvasHost);
  return feedUrl;
}

async function calendarIcsFeedForRequest(
  request: Request,
  env: Env,
  provider: CalendarIcsProvider,
): Promise<CalendarIcsFeedRow | null> {
  const sessionId = await activeSessionId(request, env.DB);
  if (!sessionId) return null;
  return env.DB.prepare(
    'SELECT * FROM calendar_ics_feeds WHERE session_id = ? AND provider = ?',
  )
    .bind(sessionId, provider)
    .first<CalendarIcsFeedRow>();
}

async function syncCalendarIcsFeed(
  request: Request,
  env: Env,
  provider: CalendarIcsProvider,
): Promise<Response> {
  const feed = await calendarIcsFeedForRequest(request, env, provider);
  if (!feed) return json({ error: `Connect ${provider} first.` }, 401);

  const feedUrl = await decrypt(feed.encrypted_feed_url, env.TOKEN_ENCRYPTION_KEY);
  const events = await fetchCalendarIcsEvents(
    provider,
    feedUrl,
    env.ALLOWED_CANVAS_HOST,
  );
  const syncedAt = new Date().toISOString();
  await env.DB.prepare(
    'UPDATE calendar_ics_feeds SET last_sync_time = ? WHERE session_id = ? AND provider = ?',
  )
    .bind(syncedAt, feed.session_id, provider)
    .run();

  return json({
    accountName: publishedCalendarName(provider),
    accountEmail: null,
    remoteUserId: feed.remote_user_id,
    providerUrl: `${provider}-published-ics`,
    providerName: provider,
    syncedAt,
    tasks: [],
    events,
  });
}

async function disconnectProvider(
  request: Request,
  env: Env,
  provider: CalendarIcsProvider,
): Promise<Response> {
  const sessionId = await activeSessionId(request, env.DB);
  if (!sessionId) return json({ disconnected: true });

  await env.DB.prepare(
    'DELETE FROM calendar_ics_feeds WHERE session_id = ? AND provider = ?',
  )
    .bind(sessionId, provider)
    .run();
  return json({ disconnected: true });
}

function publishedCalendarName(provider: CalendarIcsProvider): string {
  switch (provider) {
    case 'google':
      return 'Google Calendar published feed';
    case 'outlook':
      return 'Outlook published calendar';
    case 'canvas':
      return 'Canvas calendar feed';
    default:
      return assertNever(provider);
  }
}

function assertNever(value: never): never {
  throw new Error(`Unsupported calendar provider: ${String(value)}`);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
