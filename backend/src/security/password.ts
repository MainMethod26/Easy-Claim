/**
 * Password hashing with PBKDF2-SHA256 through WebCrypto (available in Workers, Miniflare and
 * Node 20+, so scripts/seed-demo-users.mjs produces the same format).
 *
 * Stored form: `pbkdf2-sha256$<iterations>$<salt base64>$<hash base64>`.
 * 100 000 iterations is the maximum Cloudflare Workers allow for PBKDF2.
 */
export const PBKDF2_ITERATIONS = 100_000
const SALT_BYTES = 16
const HASH_BITS = 256
const ALG = 'pbkdf2-sha256'

const enc = new TextEncoder()
const toB64 = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes))
const fromB64 = (s: string) => Uint8Array.from(atob(s), (ch) => ch.charCodeAt(0))

async function derive(password: string, salt: Uint8Array, iterations: number): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits'])
  const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt, iterations }, key, HASH_BITS)
  return new Uint8Array(bits)
}

export async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(SALT_BYTES))
  const hash = await derive(password, salt, PBKDF2_ITERATIONS)
  return `${ALG}$${PBKDF2_ITERATIONS}$${toB64(salt)}$${toB64(hash)}`
}

/** Constant-time comparison of the derived bytes; malformed stored values never verify. */
export async function verifyPassword(password: string, stored: string | null | undefined): Promise<boolean> {
  if (!stored) return false
  const [alg, iterStr, saltB64, hashB64] = stored.split('$')
  if (alg !== ALG || !iterStr || !saltB64 || !hashB64) return false
  const iterations = Number(iterStr)
  if (!Number.isInteger(iterations) || iterations < 1 || iterations > PBKDF2_ITERATIONS) return false
  let expected: Uint8Array
  try {
    expected = fromB64(hashB64)
  } catch {
    return false
  }
  const actual = await derive(password, fromB64(saltB64), iterations)
  if (actual.length !== expected.length) return false
  let diff = 0
  for (let i = 0; i < actual.length; i++) diff |= actual[i] ^ expected[i]
  return diff === 0
}

/**
 * A valid hash of a random value, used so a login attempt for an unknown username costs the
 * same time as one for a known user (no username enumeration by timing).
 */
let dummyHashPromise: Promise<string> | null = null
export function dummyHash(): Promise<string> {
  dummyHashPromise ??= hashPassword(toB64(crypto.getRandomValues(new Uint8Array(24))))
  return dummyHashPromise
}
