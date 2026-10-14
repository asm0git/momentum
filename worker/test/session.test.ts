import { afterEach, describe, expect, it, vi } from 'vitest';

import {
  activeSessionId,
  getOrCreateSession,
  nowSeconds,
  readCookie,
  SESSION_COOKIE,
  sessionCookie,
} from '../src/session';

interface StatementCall {
  sql: string;
  values: unknown[];
}

function createSessionDatabase(session: { session_id: string } | null): {
  db: D1Database;
  statements: StatementCall[];
} {
  const statements: StatementCall[] = [];
  const db = {
    prepare(sql: string) {
      const call: StatementCall = { sql, values: [] };
      statements.push(call);
      return {
        bind(...values: unknown[]) {
          call.values = values;
          return this;
        },
        async first<T>() {
          return session as T | null;
        },
        async run() {
          return {};
        },
      };
    },
  } as unknown as D1Database;
  return { db, statements };
}

afterEach(() => {
  vi.useRealTimers();
});

describe('session helpers', () => {
  it('reads the named cookie from a multi-cookie header', () => {
    const request = new Request('https://momentum.example.com', {
      headers: {
        Cookie: `theme=dark; ${SESSION_COOKIE}=session-123; other=value`,
      },
    });

    expect(readCookie(request, SESSION_COOKIE)).toBe('session-123');
    expect(readCookie(request, 'missing')).toBeNull();
  });

  it('looks up an active session using its expiry time', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'));
    const sessionId = 'session-123';
    const { db, statements } = createSessionDatabase({ session_id: sessionId });
    const request = new Request('https://momentum.example.com', {
      headers: { Cookie: `${SESSION_COOKIE}=${sessionId}` },
    });

    await expect(activeSessionId(request, db)).resolves.toBe(sessionId);
    expect(statements[0].sql).toContain('expires_at > ?');
    expect(statements[0].values).toEqual([sessionId, nowSeconds()]);
  });

  it('renews an existing session and returns a secure cookie', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'));
    const sessionId = 'session-123';
    const { db, statements } = createSessionDatabase({ session_id: sessionId });
    const request = new Request('https://momentum.example.com', {
      headers: { Cookie: `${SESSION_COOKIE}=${sessionId}` },
    });

    const result = await getOrCreateSession(request, db);

    expect(result).toEqual({ sessionId, cookie: sessionCookie(sessionId) });
    expect(result.cookie).toContain('Secure; HttpOnly; SameSite=Lax');
    expect(statements[1].sql).toContain('UPDATE sessions SET expires_at');
    expect(statements[1].values).toEqual([nowSeconds() + 60 * 60 * 24 * 30, sessionId]);
  });

  it('creates a session with a random identifier when no cookie exists', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T00:00:00Z'));
    const { db, statements } = createSessionDatabase(null);
    const request = new Request('https://momentum.example.com');

    const result = await getOrCreateSession(request, db);

    expect(result.sessionId).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(result.cookie).toBe(sessionCookie(result.sessionId));
    expect(statements).toHaveLength(1);
    expect(statements[0].sql).toContain('INSERT INTO sessions');
    expect(statements[0].values).toEqual([
      result.sessionId,
      nowSeconds() + 60 * 60 * 24 * 30,
    ]);
  });
});
