export class StoredCredentialError extends Error {
  constructor(cause: unknown) {
    super('Stored calendar credential is invalid.', { cause });
    this.name = 'StoredCredentialError';
  }
}

export async function fingerprint(value: string): Promise<string> {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return [...new Uint8Array(bytes)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

export async function encrypt(value: string, keyString: string): Promise<string> {
  const keyBytes = decodeBase64(keyString);
  if (keyBytes.length !== 32) {
    throw new Error('TOKEN_ENCRYPTION_KEY must be a 32-byte base64 key.');
  }
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

export async function decrypt(value: string, keyString: string): Promise<string> {
  let bytes: Uint8Array;
  try {
    bytes = decodeBase64(value);
  } catch (cause) {
    throw new StoredCredentialError(cause);
  }
  const keyBytes = decodeBase64(keyString);
  if (keyBytes.length !== 32) {
    throw new Error('TOKEN_ENCRYPTION_KEY must be a 32-byte base64 key.');
  }
  if (bytes.length < 13) {
    throw new StoredCredentialError(new Error('Encrypted credential is too short.'));
  }
  try {
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
  } catch (cause) {
    throw new StoredCredentialError(cause);
  }
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
