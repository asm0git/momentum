import { describe, expect, it } from 'vitest';

import {
  decrypt,
  encrypt,
  fingerprint,
  StoredCredentialError,
} from '../src/security';

function encryptionKey(): string {
  return btoa(String.fromCharCode(...new Uint8Array(32).fill(7)));
}

describe('stored calendar credentials', () => {
  it('round-trips credentials through encryption and decryption', async () => {
    const value = 'https://calendar.example/feed.ics?token=private';
    const encrypted = await encrypt(value, encryptionKey());

    expect(encrypted).not.toBe(value);
    await expect(decrypt(encrypted, encryptionKey())).resolves.toBe(value);
  });

  it('fingerprints the same value deterministically', async () => {
    const first = await fingerprint('https://calendar.example/feed.ics');
    const second = await fingerprint('https://calendar.example/feed.ics');

    expect(first).toBe(second);
    expect(await fingerprint('https://calendar.example/other.ics')).not.toBe(first);
  });

  it('normalizes invalid stored base64 and keeps the original cause', async () => {
    let thrown: unknown;
    try {
      await decrypt('%%%not-base64', encryptionKey());
    } catch (error) {
      thrown = error;
    }

    expect(thrown).toBeInstanceOf(StoredCredentialError);
    expect(thrown).toMatchObject({
      message: 'Stored calendar credential is invalid.',
      cause: expect.any(Error),
    });
  });

  it('normalizes Web Crypto authentication failures and keeps the original cause', async () => {
    const encrypted = await encrypt('https://calendar.example/feed.ics', encryptionKey());
    const bytes = Uint8Array.from(atob(encrypted), (character) => character.charCodeAt(0));
    bytes[12] ^= 1;
    const tampered = btoa(String.fromCharCode(...bytes));

    await expect(decrypt(tampered, encryptionKey())).rejects.toMatchObject({
      message: 'Stored calendar credential is invalid.',
      cause: expect.any(Error),
    });
  });
});
