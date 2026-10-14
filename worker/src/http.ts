export function json(
  value: unknown,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
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

export function mutationOriginError(
  request: Request,
  appOrigin: string,
): string | null {
  const origin = request.headers.get('Origin');
  if (!origin) return 'Origin header required for state-changing requests.';

  try {
    if (new URL(origin).origin !== new URL(appOrigin).origin) {
      return 'Cross-origin request rejected.';
    }
  } catch {
    return 'Cross-origin request rejected.';
  }

  return null;
}
