import {
  mapCanvasAssignment,
  mapCanvasEvent,
  fetchCanvasPages as getCanvasPages,
  normalizeCanvasSiteUrl,
  splitContextBatches,
} from './canvas';
import {
  CalendarIcsError,
  calendarIcsValidationError,
  fetchCalendarIcsEvents,
  normalizeCalendarIcsUrl,
} from './ics_calendar';

export interface Env {
  ASSETS: Fetcher;
  DB: D1Database;
  ALLOWED_CANVAS_HOST: string;
  APP_ORIGIN: string;
  CANVAS_CLIENT_ID: string;
  CANVAS_CLIENT_SECRET: string;
  CANVAS_REDIRECT_URI: string;
  TOKEN_ENCRYPTION_KEY: string;
  API_RATE_LIMITER?: RateLimit;
  OAUTH_RATE_LIMITER?: RateLimit;
  SYNC_RATE_LIMITER?: RateLimit;
}

interface ConnectionRow {
  session_id: string;
  canvas_url: string;
  remote_user_id: string;
  account_name: string;
  account_email: string | null;
  encrypted_access_token: string;
  encrypted_refresh_token: string | null;
  access_expires_at: number | null;
  last_sync_time: string | null;
}

const SESSION_COOKIE = '__Host-momentum_session';
const SESSION_TTL_SECONDS = 60 * 60 * 24 * 30;
const API_PAGE_SIZE = 100;
const MAX_CONTEXTS_PER_REQUEST = 10;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const url = new URL(request.url);
      const providerRoute = url.pathname.match(
        /^\/api\/(canvas|google|outlook)\/(.+)$/,
      );
      const isCanvasRoute = url.pathname.startsWith('/api/canvas/');
      if (!isCanvasRoute && !providerRoute) return env.ASSETS.fetch(request);

      if (request.method !== 'GET') assertSameOrigin(request, url);
      const limited = await enforcePublicApiLimits(request, env, url);
      if (limited) return limited;

      if (providerRoute) {
        return await providerRequest(
          request,
          env,
          providerRoute[1] as ExternalProvider,
          providerRoute[2],
        );
      }

      switch (`${request.method} ${url.pathname}`) {
        case 'GET /api/canvas/status':
          return await status(request, env);
        case 'GET /api/canvas/oauth/start':
          return await oauthStart(request, env, url);
        case 'GET /api/canvas/oauth/callback':
          return await oauthCallback(request, env, url);
        case 'POST /api/canvas/sync':
          return await syncCanvas(request, env);
        case 'POST /api/canvas/disconnect':
          return await disconnect(request, env);
        default:
          return json({ error: 'Not found.' }, 404);
      }
    } catch (error) {
      const url = new URL(request.url);
      const calendarError = error instanceof CalendarIcsError ? error : null;
      console.error(JSON.stringify({
        event: 'request_failed',
        method: request.method,
        path: url.pathname,
        error_type: error instanceof Error ? error.name : 'UnknownError',
        ...(calendarError?.diagnostics() ?? {}),
      }));
      return json(
        { error: error instanceof Error ? error.message : 'Canvas request failed.' },
        calendarError?.responseStatus ?? 400,
      );
    }
  },

  async scheduled(_controller: ScheduledController, env: Env): Promise<void> {
    try {
      await cleanupExpiredState(env.DB);
      console.log(JSON.stringify({ event: 'expired_state_cleanup_completed' }));
    } catch (error) {
      console.error(JSON.stringify({
        event: 'expired_state_cleanup_failed',
        error_type: error instanceof Error ? error.name : 'UnknownError',
      }));
      throw error;
    }
  },
};

async function enforcePublicApiLimits(
  request: Request,
  env: Env,
  url: URL,
): Promise<Response | null> {
  const isApiRequest = url.pathname.startsWith('/api/');
  const isOAuthStart = request.method === 'GET' && url.pathname.endsWith('/oauth/start');
  const isSync = request.method === 'POST' &&
    (url.pathname.endsWith('/sync') || url.pathname.endsWith('/connect'));
  if (!isApiRequest) return null;

  const edgeIp = request.headers.get('cf-connecting-ip') ?? 'unknown-client';
  if (env.API_RATE_LIMITER) {
    const { success } = await env.API_RATE_LIMITER.limit({ key: `api:${edgeIp}` });
    if (!success) return tooManyRequests(url.pathname);
  }

  if (isOAuthStart && env.OAUTH_RATE_LIMITER) {
    const { success } = await env.OAUTH_RATE_LIMITER.limit({ key: `oauth:${edgeIp}` });
    if (!success) return tooManyRequests(url.pathname);
  }

  if (isSync && env.SYNC_RATE_LIMITER) {
    const sessionId = readCookie(request, SESSION_COOKIE) ?? edgeIp;
    const { success } = await env.SYNC_RATE_LIMITER.limit({ key: `sync:${sessionId}` });
    if (!success) return tooManyRequests(url.pathname);
  }
  return null;
}

function tooManyRequests(path: string): Response {
  console.warn(JSON.stringify({ event: 'rate_limit_exceeded', path }));
  return json(
    { error: 'Too many requests. Wait a minute, then try again.' },
    429,
    { 'Retry-After': '60' },
  );
}

export async function cleanupExpiredState(db: D1Database): Promise<void> {
  const now = nowSeconds();
  await db.batch([
    db.prepare('DELETE FROM oauth_states WHERE expires_at <= ?').bind(now),
    db.prepare(`
      DELETE FROM canvas_connections
      WHERE session_id IN (SELECT session_id FROM sessions WHERE expires_at <= ?)
    `).bind(now),
    db.prepare(`
      DELETE FROM calendar_ics_feeds
      WHERE session_id IN (SELECT session_id FROM sessions WHERE expires_at <= ?)
    `).bind(now),
    db.prepare('DELETE FROM sessions WHERE expires_at <= ?').bind(now),
  ]);
}

async function oauthStart(request: Request, env: Env, url: URL): Promise<Response> {
  const siteUrl = normalizeCanvasSiteUrl(
    url.searchParams.get('siteUrl') ?? '',
    env.ALLOWED_CANVAS_HOST,
  );
  const { sessionId, cookie } = await getOrCreateSession(request, env);
  const state = randomId();
  const expiresAt = nowSeconds() + 10 * 60;
  await env.DB.prepare(
    'INSERT INTO oauth_states (state, session_id, canvas_url, expires_at) VALUES (?, ?, ?, ?)',
  )
    .bind(state, sessionId, siteUrl.origin, expiresAt)
    .run();

  const authorize = new URL('/login/oauth2/auth', siteUrl);
  authorize.searchParams.set('client_id', env.CANVAS_CLIENT_ID);
  authorize.searchParams.set('response_type', 'code');
  authorize.searchParams.set('redirect_uri', env.CANVAS_REDIRECT_URI);
  authorize.searchParams.set('state', state);
  authorize.searchParams.set(
    'scope',
    [
      'url:GET|/api/v1/courses',
      'url:GET|/api/v1/calendar_events',
      'url:GET|/api/v1/users/self/profile',
    ].join(' '),
  );

  return new Response(null, {
    status: 302,
    headers: {
      Location: authorize.toString(),
      'Cache-Control': 'no-store',
      'Set-Cookie': cookie,
    },
  });
}

async function oauthCallback(
  request: Request,
  env: Env,
  url: URL,
): Promise<Response> {
  const error = url.searchParams.get('error');
  if (error) {
    return appRedirect(
      env,
      'calendar_provider=canvas&canvas_error=authorization_cancelled',
    );
  }
  const state = url.searchParams.get('state');
  const code = url.searchParams.get('code');
  const sessionId = readCookie(request, SESSION_COOKIE);
  if (!state || !code || !sessionId) {
    return appRedirect(
      env,
      'calendar_provider=canvas&canvas_error=authorization_expired',
    );
  }
  const stateRow = await env.DB.prepare(
    'SELECT state, session_id, canvas_url FROM oauth_states WHERE state = ? AND expires_at > ?',
  )
    .bind(state, nowSeconds())
    .first<{ state: string; session_id: string; canvas_url: string }>();
  await env.DB.prepare('DELETE FROM oauth_states WHERE state = ?').bind(state).run();
  if (!stateRow || stateRow.session_id !== sessionId) {
    return appRedirect(
      env,
      'calendar_provider=canvas&canvas_error=authorization_expired',
    );
  }

  const siteUrl = normalizeCanvasSiteUrl(
    stateRow.canvas_url,
    env.ALLOWED_CANVAS_HOST,
  );
  const tokenResponse = await fetch(new URL('/login/oauth2/token', siteUrl), {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: env.CANVAS_CLIENT_ID,
      client_secret: env.CANVAS_CLIENT_SECRET,
      redirect_uri: env.CANVAS_REDIRECT_URI,
      code,
    }),
  });
  if (!tokenResponse.ok) {
    return appRedirect(
      env,
      'calendar_provider=canvas&canvas_error=token_exchange_failed',
    );
  }
  const token = (await tokenResponse.json()) as any;
  if (typeof token.access_token !== 'string' || token.user?.id == null) {
    return appRedirect(
      env,
      'calendar_provider=canvas&canvas_error=invalid_token_response',
    );
  }

  const profile = await canvasFetchJson(
    siteUrl,
    token.access_token,
    '/api/v1/users/self/profile',
  ).catch(() => token.user ?? {});
  const accountName = String(profile.name ?? token.user.name ?? 'Canvas account');
  const accountEmail = profile.primary_email ?? profile.email ?? token.user.email ?? null;
  await env.DB.prepare(`
    INSERT INTO canvas_connections
      (session_id, canvas_url, remote_user_id, account_name, account_email,
       encrypted_access_token, encrypted_refresh_token, access_expires_at, last_sync_time)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)
    ON CONFLICT(session_id) DO UPDATE SET
      canvas_url = excluded.canvas_url,
      remote_user_id = excluded.remote_user_id,
      account_name = excluded.account_name,
      account_email = excluded.account_email,
      encrypted_access_token = excluded.encrypted_access_token,
      encrypted_refresh_token = excluded.encrypted_refresh_token,
      access_expires_at = excluded.access_expires_at,
      last_sync_time = NULL
  `)
    .bind(
      sessionId,
      siteUrl.origin,
      String(profile.id ?? token.user.id),
      accountName,
      accountEmail,
      await encrypt(String(token.access_token), env.TOKEN_ENCRYPTION_KEY),
      token.refresh_token
        ? await encrypt(String(token.refresh_token), env.TOKEN_ENCRYPTION_KEY)
        : null,
      token.expires_in == null ? null : nowSeconds() + Number(token.expires_in),
    )
    .run();

  return appRedirect(
    env,
    'calendar_provider=canvas&canvas_connected=1',
    sessionCookie(sessionId),
  );
}

async function status(request: Request, env: Env): Promise<Response> {
  const connection = await connectionForRequest(request, env);
  if (!connection) return json({ connected: false });
  return json({
    connected: true,
    providerUrl: connection.canvas_url,
    accountName: connection.account_name,
    accountEmail: connection.account_email,
    remoteUserId: connection.remote_user_id,
    lastSyncTime: connection.last_sync_time,
  });
}

async function syncCanvas(request: Request, env: Env): Promise<Response> {
  const connection = await connectionForRequest(request, env);
  if (!connection) return json({ error: 'Connect a Canvas account first.' }, 401);
  const siteUrl = normalizeCanvasSiteUrl(
    connection.canvas_url,
    env.ALLOWED_CANVAS_HOST,
  );
  const accessToken = await validAccessToken(connection, siteUrl, env);
  const profile = await canvasFetchJson(
    siteUrl,
    accessToken,
    '/api/v1/users/self/profile',
  ).catch(() => ({}));
  const courses = await getCanvasPages<any>(
    siteUrl,
    accessToken,
    '/api/v1/courses?enrollment_state=active&per_page=100',
  );
  const contexts = [
    `user_${connection.remote_user_id}`,
    ...courses
      .filter((course) => course.id != null)
      .map((course) => `course_${course.id}`),
  ];
  const events: any[] = [];
  const assignments: any[] = [];
  for (const batch of splitContextBatches(contexts, MAX_CONTEXTS_PER_REQUEST)) {
    for (const type of ['event', 'assignment']) {
      const params = new URLSearchParams({
        type,
        all_events: 'true',
        per_page: String(API_PAGE_SIZE),
      });
      for (const context of batch) params.append('context_codes[]', context);
      const records = await getCanvasPages<any>(
        siteUrl,
        accessToken,
        `/api/v1/calendar_events?${params.toString()}`,
      );
      if (type === 'event') events.push(...records);
      else assignments.push(...records);
    }
  }

  const taskRecords = new Map<string, ReturnType<typeof mapCanvasAssignment>>();
  for (const record of assignments) {
    const mapped = mapCanvasAssignment(record);
    if (mapped) taskRecords.set(mapped.externalId, mapped);
  }
  const eventRecords = new Map<string, ReturnType<typeof mapCanvasEvent>>();
  for (const record of events) {
    const mapped = mapCanvasEvent(record);
    if (mapped) eventRecords.set(mapped.externalId, mapped);
  }

  const syncedAt = new Date().toISOString();
  await env.DB.prepare(
    'UPDATE canvas_connections SET last_sync_time = ? WHERE session_id = ?',
  )
    .bind(syncedAt, connection.session_id)
    .run();
  return json({
    accountName: String(profile.name ?? connection.account_name),
    accountEmail: profile.primary_email ?? profile.email ?? connection.account_email,
    remoteUserId: String(profile.id ?? connection.remote_user_id),
    providerUrl: connection.canvas_url,
    syncedAt,
    tasks: [...taskRecords.values()].filter(Boolean),
    events: [...eventRecords.values()].filter(Boolean),
  });
}

async function disconnect(request: Request, env: Env): Promise<Response> {
  const sessionId = readCookie(request, SESSION_COOKIE);
  if (sessionId) {
    await env.DB.prepare('DELETE FROM canvas_connections WHERE session_id = ?')
      .bind(sessionId)
      .run();
    await env.DB.prepare('DELETE FROM oauth_states WHERE session_id = ?')
      .bind(sessionId)
      .run();
  }
  return json({ disconnected: true });
}

type ExternalProvider = 'canvas' | 'google' | 'outlook';
interface CalendarIcsFeedRow {
  session_id: string;
  provider: ExternalProvider;
  remote_user_id: string;
  encrypted_feed_url: string;
  last_sync_time: string | null;
}

async function providerRequest(
  request: Request,
  env: Env,
  provider: ExternalProvider,
  endpoint: string,
): Promise<Response> {
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
      return syncExternalCalendar(request, env, provider);
    case 'POST disconnect':
      return disconnectProvider(request, env, provider);
    default:
      return json({ error: 'Not found.' }, 404);
  }
}

async function providerStatus(
  request: Request,
  env: Env,
  provider: ExternalProvider,
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
  provider: ExternalProvider,
): Promise<Response> {
  let body: Record<string, unknown>;
  try {
    body = await request.json() as Record<string, unknown>;
  } catch {
    throw calendarIcsValidationError(
      provider,
      `Paste a valid published ${provider} .ics link.`,
    );
  }
  if (typeof body.url !== 'string') {
    throw calendarIcsValidationError(
      provider,
      `Paste a valid published ${provider} .ics link.`,
    );
  }
  const feedUrl = normalizeCalendarIcsUrl(
    provider,
    body.url,
    env.ALLOWED_CANVAS_HOST,
  ).toString();
  // Validate the link before saving it, so a typo never replaces a working feed.
  await fetchCalendarIcsEvents(provider, feedUrl, env.ALLOWED_CANVAS_HOST);
  const { sessionId, cookie } = await getOrCreateSession(request, env);
  const remoteUserId = await fingerprint(feedUrl);
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
      remoteUserId,
      await encrypt(feedUrl, env.TOKEN_ENCRYPTION_KEY),
    )
    .run();
  if (provider === 'canvas') {
    await env.DB.prepare('DELETE FROM canvas_connections WHERE session_id = ?')
      .bind(sessionId)
      .run();
    await env.DB.prepare('DELETE FROM oauth_states WHERE session_id = ?')
      .bind(sessionId)
      .run();
  }
  return json({ connected: true }, 200, { 'Set-Cookie': cookie });
}

function publishedCalendarName(provider: ExternalProvider): string {
  return provider === 'google'
    ? 'Google Calendar published feed'
    : provider === 'outlook'
      ? 'Outlook published calendar'
      : 'Canvas calendar feed';
}

async function calendarIcsFeedForRequest(
  request: Request,
  env: Env,
  provider: ExternalProvider,
): Promise<CalendarIcsFeedRow | null> {
  const sessionId = readCookie(request, SESSION_COOKIE);
  if (!sessionId) return null;
  const session = await env.DB.prepare(
    'SELECT session_id FROM sessions WHERE session_id = ? AND expires_at > ?',
  )
    .bind(sessionId, nowSeconds())
    .first();
  if (!session) return null;
  return env.DB.prepare(
    'SELECT * FROM calendar_ics_feeds WHERE session_id = ? AND provider = ?',
  )
    .bind(sessionId, provider)
    .first<CalendarIcsFeedRow>();
}

async function syncCalendarIcsFeed(
  request: Request,
  env: Env,
  provider: ExternalProvider,
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

async function fingerprint(value: string): Promise<string> {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return [...new Uint8Array(bytes)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

async function disconnectProvider(
  request: Request,
  env: Env,
  provider: ExternalProvider,
): Promise<Response> {
  const sessionId = readCookie(request, SESSION_COOKIE);
  if (sessionId) {
    await env.DB.prepare(
      'DELETE FROM calendar_ics_feeds WHERE session_id = ? AND provider = ?',
    )
      .bind(sessionId, provider)
      .run();
    if (provider === 'canvas') {
      await env.DB.prepare('DELETE FROM canvas_connections WHERE session_id = ?')
        .bind(sessionId)
        .run();
      await env.DB.prepare('DELETE FROM oauth_states WHERE session_id = ?')
        .bind(sessionId)
        .run();
    }
  }
  return json({ disconnected: true });
}

async function getOrCreateSession(
  request: Request,
  env: Env,
): Promise<{ sessionId: string; cookie: string }> {
  const current = readCookie(request, SESSION_COOKIE);
  if (current) {
    const session = await env.DB.prepare(
      'SELECT session_id FROM sessions WHERE session_id = ? AND expires_at > ?',
    )
      .bind(current, nowSeconds())
      .first();
    if (session) {
      await env.DB.prepare('UPDATE sessions SET expires_at = ? WHERE session_id = ?')
        .bind(nowSeconds() + SESSION_TTL_SECONDS, current)
        .run();
      return { sessionId: current, cookie: sessionCookie(current) };
    }
  }
  const sessionId = randomId();
  await env.DB.prepare('INSERT INTO sessions (session_id, expires_at) VALUES (?, ?)')
    .bind(sessionId, nowSeconds() + SESSION_TTL_SECONDS)
    .run();
  return { sessionId, cookie: sessionCookie(sessionId) };
}

async function syncExternalCalendar(
  request: Request,
  env: Env,
  provider: ExternalProvider,
): Promise<Response> {
  return syncCalendarIcsFeed(request, env, provider);
}

async function connectionForRequest(
  request: Request,
  env: Env,
): Promise<ConnectionRow | null> {
  const sessionId = readCookie(request, SESSION_COOKIE);
  if (!sessionId) return null;
  const session = await env.DB.prepare(
    'SELECT session_id FROM sessions WHERE session_id = ? AND expires_at > ?',
  )
    .bind(sessionId, nowSeconds())
    .first();
  if (!session) return null;
  return env.DB.prepare(
    'SELECT * FROM canvas_connections WHERE session_id = ?',
  )
    .bind(sessionId)
    .first<ConnectionRow>();
}

async function validAccessToken(
  connection: ConnectionRow,
  siteUrl: URL,
  env: Env,
): Promise<string> {
  if (
    connection.access_expires_at == null ||
    connection.access_expires_at > nowSeconds() + 60
  ) {
    return decrypt(connection.encrypted_access_token, env.TOKEN_ENCRYPTION_KEY);
  }
  if (!connection.encrypted_refresh_token) {
    throw new Error('Canvas authorization expired. Reconnect your account.');
  }
  const refreshToken = await decrypt(
    connection.encrypted_refresh_token,
    env.TOKEN_ENCRYPTION_KEY,
  );
  const response = await fetch(new URL('/login/oauth2/token', siteUrl), {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      client_id: env.CANVAS_CLIENT_ID,
      client_secret: env.CANVAS_CLIENT_SECRET,
      refresh_token: refreshToken,
    }),
  });
  if (!response.ok) throw new Error('Canvas authorization expired. Reconnect your account.');
  const refreshed = (await response.json()) as any;
  const nextAccess = String(refreshed.access_token);
  const nextRefresh = String(refreshed.refresh_token ?? refreshToken);
  await env.DB.prepare(`
    UPDATE canvas_connections SET encrypted_access_token = ?,
      encrypted_refresh_token = ?, access_expires_at = ? WHERE session_id = ?
  `)
    .bind(
      await encrypt(nextAccess, env.TOKEN_ENCRYPTION_KEY),
      await encrypt(nextRefresh, env.TOKEN_ENCRYPTION_KEY),
      refreshed.expires_in == null ? null : nowSeconds() + Number(refreshed.expires_in),
      connection.session_id,
    )
    .run();
  return nextAccess;
}

async function canvasFetchJson(
  siteUrl: URL,
  token: string,
  path: string,
): Promise<any> {
  const response = await fetch(new URL(path, siteUrl), {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!response.ok) throw new Error(`Canvas API request failed (${response.status}).`);
  return response.json();
}

async function encrypt(value: string, keyString: string): Promise<string> {
  const keyBytes = decodeBase64(keyString);
  if (keyBytes.length !== 32) throw new Error('TOKEN_ENCRYPTION_KEY must be a 32-byte base64 key.');
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await crypto.subtle.importKey(
    'raw',
    toArrayBuffer(keyBytes),
    'AES-GCM',
    false,
    ['encrypt'],
  );
  const cipher = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    new TextEncoder().encode(value),
  );
  return encodeBase64(joinBytes(iv, new Uint8Array(cipher)));
}

async function decrypt(value: string, keyString: string): Promise<string> {
  const bytes = decodeBase64(value);
  const keyBytes = decodeBase64(keyString);
  if (keyBytes.length !== 32 || bytes.length < 13) throw new Error('Stored Canvas credential is invalid.');
  const key = await crypto.subtle.importKey(
    'raw',
    toArrayBuffer(keyBytes),
    'AES-GCM',
    false,
    ['decrypt'],
  );
  const plain = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: bytes.slice(0, 12) },
    key,
    bytes.slice(12),
  );
  return new TextDecoder().decode(plain);
}

function decodeBase64(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function encodeBase64(value: Uint8Array): string {
  let binary = '';
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function joinBytes(first: Uint8Array, second: Uint8Array): Uint8Array {
  const output = new Uint8Array(first.length + second.length);
  output.set(first, 0);
  output.set(second, first.length);
  return output;
}

function toArrayBuffer(value: Uint8Array): ArrayBuffer {
  const buffer = new ArrayBuffer(value.byteLength);
  new Uint8Array(buffer).set(value);
  return buffer;
}

function readCookie(request: Request, name: string): string | null {
  const cookies = request.headers.get('Cookie')?.split(';') ?? [];
  for (const cookie of cookies) {
    const [key, ...value] = cookie.trim().split('=');
    if (key === name) return value.join('=') || null;
  }
  return null;
}

function sessionCookie(sessionId: string): string {
  return `${SESSION_COOKIE}=${sessionId}; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=${SESSION_TTL_SECONDS}`;
}

function appRedirect(env: Env, query = '', cookie?: string): Response {
  const target = new URL('/', env.APP_ORIGIN);
  if (query) target.search = query;
  const headers = new Headers({ Location: target.toString(), 'Cache-Control': 'no-store' });
  if (cookie) headers.set('Set-Cookie', cookie);
  return new Response(null, { status: 302, headers });
}

function assertSameOrigin(request: Request, requestUrl: URL): void {
  const origin = request.headers.get('Origin');
  if (origin && new URL(origin).origin !== requestUrl.origin) {
    throw new Error('Cross-origin request rejected.');
  }
}

function randomId(): string {
  return encodeBase64(crypto.getRandomValues(new Uint8Array(32)))
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

function nowSeconds(): number {
  return Math.floor(Date.now() / 1000);
}

function json(value: unknown, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer',
      ...extraHeaders,
    },
  });
}

export {
  fetchCanvasPages,
  mapCanvasAssignment,
  mapCanvasEvent,
  nextCanvasPage,
  normalizeCanvasSiteUrl,
  splitContextBatches,
} from './canvas';
