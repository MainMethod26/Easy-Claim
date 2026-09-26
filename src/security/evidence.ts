/**
 * Evidence upload validation and integrity helpers (Phase 2).
 *
 * Uploaded files are untrusted input: the declared MIME type, filename and extension are
 * client-controlled and are never trusted alone. See docs/security/EVIDENCE_SECURITY.md.
 */

/** Only these types are accepted. Reject archives, Office documents and SVG outright. */
export const ALLOWED_EVIDENCE_TYPES = ['application/pdf', 'image/jpeg', 'image/png'] as const
export type AllowedEvidenceType = (typeof ALLOWED_EVIDENCE_TYPES)[number]

export const MAX_EVIDENCE_BYTES = 10 * 1024 * 1024

/** Leading bytes ("magic numbers") for each allowed type, checked against the actual content. */
const MAGIC_BYTES: Record<AllowedEvidenceType, number[]> = {
  'application/pdf': [0x25, 0x50, 0x44, 0x46, 0x2d], // %PDF-
  'image/jpeg': [0xff, 0xd8, 0xff],
  'image/png': [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
}

export function isAllowedEvidenceType(value: string): value is AllowedEvidenceType {
  return (ALLOWED_EVIDENCE_TYPES as readonly string[]).includes(value)
}

/** The declared MIME type must agree with the file's actual leading bytes. */
export function matchesMagicBytes(bytes: Uint8Array, declaredType: AllowedEvidenceType): boolean {
  const magic = MAGIC_BYTES[declaredType]
  if (bytes.length < magic.length) return false
  return magic.every((b, i) => bytes[i] === b)
}

const UNSAFE_FILENAME_CHARS = /[^A-Za-z0-9._-]/g

/**
 * Strips any directory component and non-portable characters from a client-supplied filename.
 * The result is stored only as display metadata; it never contributes to the storage key.
 */
export function sanitizeFilename(name: string | undefined | null): string {
  const base = (name ?? '').split(/[\\/]/).pop() ?? ''
  const cleaned = base.replace(UNSAFE_FILENAME_CHARS, '_').slice(0, 128)
  return cleaned.length > 0 ? cleaned : 'evidence'
}

export async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', bytes)
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
}
