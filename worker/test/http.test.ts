import { describe, expect, it } from 'vitest';

import { json, mutationOriginError } from '../src/http';

describe('HTTP response helpers', () => {
  it('serializes JSON with safe defaults and supports response overrides', async () => {
    const response = json({ ready: true }, 201, { 'Cache-Control': 'private' });

    expect(response.status).toBe(201);
    expect(response.headers.get('Content-Type')).toBe('application/json; charset=utf-8');
    expect(response.headers.get('Cache-Control')).toBe('private');
    expect(response.headers.get('X-Content-Type-Options')).toBe('nosniff');
    expect(response.headers.get('Referrer-Policy')).toBe('no-referrer');
    await expect(response.json()).resolves.toEqual({ ready: true });
  });

  it('accepts same-origin state changes and rejects missing or foreign origins', () => {
    const appOrigin = 'https://momentum.example.com';
    const sameOrigin = new Request('https://momentum.example.com/api/calendar', {
      method: 'POST',
      headers: { Origin: 'https://momentum.example.com' },
    });
    const foreignOrigin = new Request('https://momentum.example.com/api/calendar', {
      method: 'POST',
      headers: { Origin: 'https://attacker.example' },
    });
    const missingOrigin = new Request('https://momentum.example.com/api/calendar', {
      method: 'POST',
    });

    expect(mutationOriginError(sameOrigin, appOrigin)).toBeNull();
    expect(mutationOriginError(foreignOrigin, appOrigin)).toBe('Cross-origin request rejected.');
    expect(mutationOriginError(missingOrigin, appOrigin))
      .toBe('Origin header required for state-changing requests.');
  });

  it('rejects malformed configured origins safely', () => {
    const request = new Request('https://momentum.example.com/api/calendar', {
      method: 'POST',
      headers: { Origin: 'https://momentum.example.com' },
    });

    expect(mutationOriginError(request, 'not a valid URL'))
      .toBe('Cross-origin request rejected.');
  });
});
