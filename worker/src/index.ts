import {
  CalendarIcsError,
  type CalendarIcsProvider,
} from './ics_calendar';
import { handleProviderRequest } from './calendar_feed_routes';
import type { Env } from './env';
import { json, mutationOriginError } from './http';
import { cleanupExpiredState, readCookie, SESSION_COOKIE } from './session';

export type { Env } from './env';
export { cleanupExpiredState } from './session';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const url = new URL(request.url);
      const route = providerRoute(url.pathname);
      if (!route) return env.ASSETS.fetch(request);

      if (request.method !== 'GET') {
        const originError = mutationOriginError(request, env.APP_ORIGIN);
        if (originError) return json({ error: originError }, 403);
      }

      const limited = await enforcePublicApiLimits(request, env, url);
      if (limited) return limited;

      return await handleProviderRequest(
        request,
        env,
        route.provider,
        route.endpoint,
      );
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
        { error: error instanceof Error ? error.message : 'Calendar request failed.' },
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

function providerRoute(path: string): {
  provider: CalendarIcsProvider;
  endpoint: string;
} | null {
  const match = path.match(/^\/api\/([^/]+)\/(.*)$/);
  if (!match || !isCalendarIcsProvider(match[1])) return null;
  return {
    provider: match[1],
    endpoint: match[2],
  };
}

function isCalendarIcsProvider(value: string): value is CalendarIcsProvider {
  return value === 'canvas' || value === 'google' || value === 'outlook';
}

async function enforcePublicApiLimits(
  request: Request,
  env: Env,
  url: URL,
): Promise<Response | null> {
  const isOAuthStart = request.method === 'GET' && url.pathname.endsWith('/oauth/start');
  const isSync = request.method === 'POST' &&
    (url.pathname.endsWith('/sync') || url.pathname.endsWith('/connect'));
  const edgeIp = request.headers.get('cf-connecting-ip') ?? 'unknown-client';

  if (await isRateLimited(env.API_RATE_LIMITER, `api:${edgeIp}`)) {
    return tooManyRequests(url.pathname);
  }

  if (isOAuthStart && await isRateLimited(env.OAUTH_RATE_LIMITER, `oauth:${edgeIp}`)) {
    return tooManyRequests(url.pathname);
  }

  if (isSync && env.SYNC_RATE_LIMITER) {
    const sessionId = readCookie(request, SESSION_COOKIE) ?? edgeIp;
    if (await isRateLimited(env.SYNC_RATE_LIMITER, `sync:${sessionId}`)) {
      return tooManyRequests(url.pathname);
    }
  }
  return null;
}

async function isRateLimited(
  limiter: RateLimit | undefined,
  key: string,
): Promise<boolean> {
  if (!limiter) return false;
  const { success } = await limiter.limit({ key });
  return !success;
}

function tooManyRequests(path: string): Response {
  console.warn(JSON.stringify({ event: 'rate_limit_exceeded', path }));
  return json(
    { error: 'Too many requests. Wait a minute, then try again.' },
    429,
    { 'Retry-After': '60' },
  );
}
