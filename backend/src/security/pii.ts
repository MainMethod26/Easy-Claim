/**
 * Field-level encryption for personal identifiers (SA ID numbers), AES-256-GCM.
 *
 * Key: the PII_KEY secret (64 hex chars = 32 bytes), separate from JWT_SECRET and MLDSA_SEED so one
 * leak does not expose the others. Missing or malformed key → callers answer 503 (fail closed);
 * nothing is ever stored in plain text as a fallback.
 *
 * Stored format: base64(iv[12] || ciphertext+tag). A fresh random IV per value.
 */

const enc = new TextEncoder()
const dec = new TextDecoder()

function keyBytes(hex: string | undefined): Uint8Array | null {
  if (!hex || !/^[0-9a-fA-F]{64}$/.test(hex)) return null
  const out = new Uint8Array(32)
  for (let i = 0; i < 32; i++) out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16)
  return out
}

async function importKey(hex: string | undefined): Promise<CryptoKey | null> {
  const raw = keyBytes(hex)
  if (!raw) return null
  return crypto.subtle.importKey('raw', raw, 'AES-GCM', false, ['encrypt', 'decrypt'])
}

const b64 = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes))
const unb64 = (s: string) => Uint8Array.from(atob(s), (ch) => ch.charCodeAt(0))

/** Encrypts `plaintext`; null when the key is unavailable. */
export async function encryptField(keyHex: string | undefined, plaintext: string): Promise<string | null> {
  const key = await importKey(keyHex)
  if (!key) return null
  const iv = crypto.getRandomValues(new Uint8Array(12))
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, enc.encode(plaintext)))
  const out = new Uint8Array(iv.length + ct.length)
  out.set(iv)
  out.set(ct, iv.length)
  return b64(out)
}

/** Decrypts a value from encryptField; null when the key is unavailable or the value was tampered with. */
export async function decryptField(keyHex: string | undefined, stored: string): Promise<string | null> {
  const key = await importKey(keyHex)
  if (!key) return null
  try {
    const all = unb64(stored)
    const pt = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: all.slice(0, 12) }, key, all.slice(12))
    return dec.decode(pt)
  } catch {
    return null
  }
}

/** South African ID number: 13 digits, a valid date of birth prefix, and a Luhn check digit. */
export function isValidSaIdNumber(id: string): boolean {
  if (!/^[0-9]{13}$/.test(id)) return false
  const mm = Number(id.slice(2, 4))
  const dd = Number(id.slice(4, 6))
  if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return false
  let sum = 0
  for (let i = 0; i < 13; i++) {
    let d = Number(id[12 - i])
    if (i % 2 === 1) {
      d *= 2
      if (d > 9) d -= 9
    }
    sum += d
  }
  return sum % 10 === 0
}

/** "******** *1234": only the last four digits are ever shown without an audited reveal. */
export const maskIdNumber = (last4: string) => `•••••••••${last4}`
