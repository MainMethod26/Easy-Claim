import { Hono } from 'hono'
import type { AppEnv } from '../types'
import { requireRole } from '../security/rbac'
import { writeAuditEvent } from '../security/audit'
import { loadAuthorizedClaim } from '../security/claimAccess'
import { claimEvidenceParam, claimIdParam, validate } from '../security/validation'
import {
  ALLOWED_EVIDENCE_TYPES,
  MAX_EVIDENCE_BYTES,
  isAllowedEvidenceType,
  matchesMagicBytes,
  sanitizeFilename,
  sha256Hex,
} from '../security/evidence'

/**
 * Claim evidence: photographs, documents, receipts and other supporting material.
 *
 * Every route follows: AUTHENTICATE (app-level) -> IDENTIFY ACTOR -> TENANT/CONTEXT ->
 * VALIDATE CLAIM -> VERIFY ACCESS (loadAuthorizedClaim) -> VALIDATE EVIDENCE -> STORE
 * PRIVATELY -> CALCULATE HASH -> STORE METADATA -> AUDIT. See docs/security/EVIDENCE_SECURITY.md.
 */
const router = new Hono<AppEnv>()

const notFound = { error: 'not_found' } as const

interface EvidenceRow {
  id: string
  claim_id: string
  tenant_id: string | null
  uploaded_by: string
  storage_key: string
  display_name: string
  mime_type: string
  size_bytes: number
  sha256: string
  created_at: string
}

async function loadEvidenceRow(db: D1Database, claimId: string, evidenceId: string) {
  return db
    .prepare('SELECT * FROM evidence WHERE id = ? AND claim_id = ?')
    .bind(evidenceId, claimId)
    .first<EvidenceRow>()
}

// List evidence metadata for a claim: the owning customer or that tenant's insurer staff.
router.get('/:claimId/evidence', validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'read')
  if (!claim) return c.json(notFound, 404)

  const { results } = await c.env.DB.prepare(
    `SELECT id, display_name, mime_type, size_bytes, sha256, created_at
     FROM evidence WHERE claim_id = ? ORDER BY created_at, id`
  )
    .bind(claim.id)
    .all()
  return c.json({ evidence: results })
})

// Upload a file. Never trusts a client-supplied owner, tenant, claim id (beyond the URL,
// which is re-authorized) or MIME type. The route accepts multipart/form-data, field "file".
router.post('/:claimId/evidence', requireRole('CUSTOMER'), validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'owner-write')
  if (!claim) return c.json(notFound, 404)

  if (claim.stage !== 'Draft' && claim.stage !== 'Info Needed') {
    return c.json({ error: 'claim_not_editable', stage: claim.stage }, 409)
  }

  if (!c.env.EVIDENCE_BUCKET) {
    console.error(`[${c.get('requestId')}] evidence upload refused: EVIDENCE_BUCKET is not bound`)
    return c.json({ error: 'storage_unavailable' }, 503)
  }

  let form: Record<string, string | File>
  try {
    form = await c.req.parseBody()
  } catch {
    return c.json({ error: 'invalid_upload' }, 400)
  }

  const file = form['file']
  if (!(file instanceof File)) {
    return c.json({ error: 'file_required' }, 400)
  }

  if (file.size <= 0 || file.size > MAX_EVIDENCE_BYTES) {
    await writeAuditEvent(c, {
      action: 'evidence.rejected',
      resourceType: 'claim',
      resourceId: claim.id,
      outcome: 'denied',
      details: { reason: 'size', sizeBytes: file.size },
    })
    return c.json({ error: 'file_too_large', maxBytes: MAX_EVIDENCE_BYTES }, 413)
  }

  // The declared type (from the client) is only a starting filter; matchesMagicBytes below
  // checks it against the actual bytes so a relabeled file cannot slip through.
  const declaredType = file.type
  if (!isAllowedEvidenceType(declaredType)) {
    await writeAuditEvent(c, {
      action: 'evidence.rejected',
      resourceType: 'claim',
      resourceId: claim.id,
      outcome: 'denied',
      details: { reason: 'unsupported_type', declaredType },
    })
    return c.json({ error: 'unsupported_file_type', allowed: ALLOWED_EVIDENCE_TYPES }, 415)
  }

  const bytes = new Uint8Array(await file.arrayBuffer())
  if (!matchesMagicBytes(bytes, declaredType)) {
    await writeAuditEvent(c, {
      action: 'evidence.rejected',
      resourceType: 'claim',
      resourceId: claim.id,
      outcome: 'denied',
      details: { reason: 'magic_bytes_mismatch', declaredType },
    })
    return c.json({ error: 'unsupported_file_type', allowed: ALLOWED_EVIDENCE_TYPES }, 415)
  }

  const actor = c.get('actor')
  const evidenceId = `ev_${crypto.randomUUID()}`
  // Never the client filename: a fresh, unguessable, server-generated key.
  const storageKey = `claims/${claim.id}/${evidenceId}`
  const hash = await sha256Hex(bytes)
  const displayName = sanitizeFilename(file.name)
  const now = new Date().toISOString()

  await c.env.EVIDENCE_BUCKET.put(storageKey, bytes, { httpMetadata: { contentType: declaredType } })

  // Ownership, tenant and claim association are all server-derived from the authorized claim
  // and verified actor above; nothing here comes from the request body.
  await c.env.DB.prepare(
    `INSERT INTO evidence (id, claim_id, tenant_id, uploaded_by, storage_key, display_name, mime_type, size_bytes, sha256, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(evidenceId, claim.id, claim.tenant_id, actor.id, storageKey, displayName, declaredType, bytes.byteLength, hash, now)
    .run()

  await writeAuditEvent(c, {
    action: 'evidence.uploaded',
    resourceType: 'evidence',
    resourceId: evidenceId,
    outcome: 'success',
    details: { claimId: claim.id, mimeType: declaredType, sizeBytes: bytes.byteLength, sha256: hash },
  })

  await c.env.CLAIM_EVENTS?.send({ event: 'ClaimEvidenceUploaded', data: { claimId: claim.id, timestamp: now } })

  return c.json({ status: 'uploaded', evidenceId, sha256: hash }, 201)
})

// Download the original bytes. Server-controlled retrieval only: never a predictable public
// URL. Authorization mirrors claim access (owner, or that tenant's insurer staff).
router.get('/:claimId/evidence/:evidenceId', validate('param', claimEvidenceParam), async (c) => {
  const { claimId, evidenceId } = c.req.valid('param')
  const claim = await loadAuthorizedClaim(c, claimId, 'read')
  if (!claim) return c.json(notFound, 404)

  const row = await loadEvidenceRow(c.env.DB, claim.id, evidenceId)
  if (!row) return c.json(notFound, 404)

  if (!c.env.EVIDENCE_BUCKET) {
    console.error(`[${c.get('requestId')}] evidence download refused: EVIDENCE_BUCKET is not bound`)
    return c.json({ error: 'storage_unavailable' }, 503)
  }
  const object = await c.env.EVIDENCE_BUCKET.get(row.storage_key)
  if (!object) return c.json(notFound, 404)

  await writeAuditEvent(c, {
    action: 'evidence.accessed',
    resourceType: 'evidence',
    resourceId: row.id,
    outcome: 'success',
    details: { claimId: claim.id },
  })

  return new Response(object.body, {
    headers: {
      'Content-Type': row.mime_type,
      // display_name is sanitized to [A-Za-z0-9._-] only, so it cannot break out of the quotes.
      'Content-Disposition': `attachment; filename="${row.display_name}"`,
      'Cache-Control': 'private, no-store',
    },
  })
})

// Integrity verification: recomputes SHA-256 over the stored bytes and compares it against
// the hash captured at upload time. Hashing detects modification; it does not by itself
// control access -- authorization above and private storage do that.
router.get('/:claimId/evidence/:evidenceId/verify', validate('param', claimEvidenceParam), async (c) => {
  const { claimId, evidenceId } = c.req.valid('param')
  const claim = await loadAuthorizedClaim(c, claimId, 'read')
  if (!claim) return c.json(notFound, 404)

  const row = await loadEvidenceRow(c.env.DB, claim.id, evidenceId)
  if (!row) return c.json(notFound, 404)

  if (!c.env.EVIDENCE_BUCKET) {
    console.error(`[${c.get('requestId')}] evidence verification refused: EVIDENCE_BUCKET is not bound`)
    return c.json({ error: 'storage_unavailable' }, 503)
  }
  const object = await c.env.EVIDENCE_BUCKET.get(row.storage_key)
  if (!object) {
    await writeAuditEvent(c, {
      action: 'evidence.integrity_verified',
      resourceType: 'evidence',
      resourceId: row.id,
      outcome: 'failure',
      details: { claimId: claim.id, reason: 'object_missing' },
    })
    return c.json({ status: 'TAMPERED', evidenceId: row.id, reason: 'object_missing' })
  }

  const actualHash = await sha256Hex(new Uint8Array(await object.arrayBuffer()))
  const valid = actualHash === row.sha256

  await writeAuditEvent(c, {
    action: 'evidence.integrity_verified',
    resourceType: 'evidence',
    resourceId: row.id,
    outcome: valid ? 'success' : 'failure',
    details: { claimId: claim.id, expectedHash: row.sha256, actualHash },
  })

  return c.json({ status: valid ? 'VALID' : 'TAMPERED', evidenceId: row.id, expectedHash: row.sha256, actualHash })
})

export default router
