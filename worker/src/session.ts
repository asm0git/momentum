export const SESSION_COOKIE = '__Host-momentum_session';
const SECONDS_PER_DAY = 24 * 60 * 60;
const SESSION_TTL_DAYS = 30;
const SESSION_TTL_SECONDS = SESSION_TTL_DAYS * SECONDS_PER_DAY;

export function readCookie(request: Request, name: string): string | null {
  const cookies = request.headers.get('Cookie')?.split(';') ?? [];
  for (const cookie of cookies) {
    const [key, ...value] = cookie.trim().split('=');
    if (key === name) return value.join('=') || null;
  }
  return null;
}

export function sessionCookie(sessionId: string): string {
  return `${SESSION_COOKIE}=${sessionId}; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=${SESSION_TTL_SECONDS}`;
}

export function nowSeconds(): number {
  return Math.floor(Date.now() / 1000);
}

export function randomId(): string {
  return encodeBase64(crypto.getRandomValues(new Uint8Array(32)))
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

export async function getOrCreateSession(
  request: Request,
  db: D1Database,
): Promise<{ sessionId: string; cookie: string }> {
  const current = readCookie(request, SESSION_COOKIE);
  if (current) {
    const session = await db.prepare(
      'SELECT session_id FROM sessions WHERE session_id = ? AND expires_at > ?',
    )
      .bind(current, nowSeconds())
      .first<{ session_id: string }>();
    if (session) {
      await db.prepare('UPDATE sessions SET expires_at = ? WHERE session_id = ?')
        .bind(nowSeconds() + SESSION_TTL_SECONDS, current)
        .run();
      return { sessionId: current, cookie: sessionCookie(current) };
    }
  }

  const sessionId = randomId();
  await db.prepare('INSERT INTO sessions (session_id, expires_at) VALUES (?, ?)')
    .bind(sessionId, nowSeconds() + SESSION_TTL_SECONDS)
    .run();
  return { sessionId, cookie: sessionCookie(sessionId) };
}

export async function activeSessionId(
  request: Request,
  db: D1Database,
): Promise<string | null> {
  const sessionId = readCookie(request, SESSION_COOKIE);
  if (!sessionId) return null;
  const session = await db.prepare(
    'SELECT session_id FROM sessions WHERE session_id = ? AND expires_at > ?',
  )
    .bind(sessionId, nowSeconds())
    .first<{ session_id: string }>();
  return session?.session_id ?? null;
}

export async function cleanupExpiredState(db: D1Database): Promise<void> {
  const now = nowSeconds();
  await db.batch([
    db.prepare(`
      DELETE FROM calendar_ics_feeds
      WHERE session_id IN (SELECT session_id FROM sessions WHERE expires_at <= ?)
    `).bind(now),
    db.prepare('DELETE FROM sessions WHERE expires_at <= ?').bind(now),
  ]);
}

function encodeBase64(value: Uint8Array): string {
  let binary = '';
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary);
}
