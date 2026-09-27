/**
 * Customer onboarding with documents (migration 0012). Builds on policy linking in ./service.ts:
 *
 *   customer: EasyClaim ID + profile (ID number encrypted) → picks insurers → request per insurer →
 *             uploads that insurer's required documents
 *   insurer admin: sees the client (ID masked, audited reveal), opens and checks each document,
 *             then approves (only when every required document is uploaded and checked), asks for
 *             more information (request goes back to the customer) or declines.
 *
 * Scope always comes from the verified actor (customer = own user id, insurer admin = token tenant);
 * another tenant's request is indistinguishable from a missing one (404). Documents are private R2
 * objects served only through audited, authenticated routes.
 */
import type { Context } from 'hono'
import type { AppEnv } from '../types'
import { auditStatement, writeAuditEvent } from '../security/audit'
import { decryptField, encryptField, isValidSaIdNumber, maskIdNumber } from '../security/pii'
import { MAX_EVIDENCE_BYTES, isAllowedEvidenceType, matchesMagicBytes, sanitizeFilename, sha256Hex, ALLOWED_EVIDENCE_TYPES } from '../security/evidence'
import type { Outcome } from './service'
import { latestConsent } from '../consent/service'

type C = Context<AppEnv>
const now = () => new Date().toISOString()

// ------------------------------------------------------------------ EasyClaim ID

const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ' // Crockford base32: no I, L, O, U
export const EASYCLAIM_ID_PATTERN = /^EC-[0-9A-Z]{4}-[0-9A-Z]{4}$/

export function newEasyclaimId(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(8))
  const chars = Array.from(bytes, (b) => ALPHABET[b % 32]).join('')
  return `EC-${chars.slice(0, 4)}-${chars.slice(4)}`
}

/** Returns the customer's EasyClaim ID, creating one on first use (older accounts). */
export async function ensureEasyclaimId(db: D1Database, userId: string): Promise<string> {
  const row = await db.prepare('SELECT easyclaim_id FROM users WHERE id = ?').bind(userId).first<{ easyclaim_id: string | null }>()
  if (row?.easyclaim_id) return row.easyclaim_id
  for (let attempt = 0; attempt < 5; attempt++) {
    const id = newEasyclaimId()
    try {
      const r = await db.prepare('UPDATE users SET easyclaim_id = ? WHERE id = ? AND easyclaim_id IS NULL').bind(id, userId).run()
      if (r.meta.changes === 1) return id
      const again = await db.prepare('SELECT easyclaim_id FROM users WHERE id = ?').bind(userId).first<{ easyclaim_id: string | null }>()
      if (again?.easyclaim_id) return again.easyclaim_id
    } catch (err) {
      if (!String(err).includes('UNIQUE')) throw err
    }
  }
  throw new Error('could not allocate an EasyClaim ID')
}

// ------------------------------------------------------------------ profile

export interface CustomerProfileDto {
  legalName: string
  email: string
  phone: string
  dateOfBirth: string
  /** Always masked here; the full number needs an audited reveal by the insurer. */
  idNumberMasked: string
  updatedAt: string
}

interface ProfileRow {
  legal_name: string
  email: string
  phone: string
  date_of_birth: string
  id_number_enc: string
  id_number_last4: string
  updated_at: string
}

const toProfile = (r: ProfileRow): CustomerProfileDto => ({
  legalName: r.legal_name,
  email: r.email,
  phone: r.phone,
  dateOfBirth: r.date_of_birth,
  idNumberMasked: maskIdNumber(r.id_number_last4),
  updatedAt: r.updated_at,
})

async function loadProfile(db: D1Database, userId: string) {
  return db.prepare('SELECT * FROM customer_profiles WHERE user_id = ?').bind(userId).first<ProfileRow>()
}

export async function getMyProfile(c: C) {
  const actor = c.get('actor')
  const easyclaimId = await ensureEasyclaimId(c.env.DB, actor.id)
  const row = await loadProfile(c.env.DB, actor.id)
  return { easyclaimId, profile: row ? toProfile(row) : null }
}

export async function saveMyProfile(
  c: C,
  input: { legalName: string; email: string; phone: string; dateOfBirth: string; idNumber: string }
): Promise<Outcome<{ easyclaimId: string; profile: CustomerProfileDto }>> {
  if (!isValidSaIdNumber(input.idNumber)) return { ok: false, status: 400, error: 'invalid_id_number' }
  // The ID number encodes the date of birth (YYMMDD); they must agree.
  if (input.idNumber.slice(0, 6) !== input.dateOfBirth.slice(2, 4) + input.dateOfBirth.slice(5, 7) + input.dateOfBirth.slice(8, 10)) {
    return { ok: false, status: 400, error: 'id_number_date_mismatch' }
  }
  const encrypted = await encryptField(c.env.PII_KEY, input.idNumber)
  if (!encrypted) {
    console.error(`[${c.get('requestId')}] profile refused: PII_KEY missing or malformed`)
    return { ok: false, status: 503, error: 'pii_unavailable' }
  }
  const actor = c.get('actor')
  const at = now()
  await c.env.DB.batch([
    c.env.DB.prepare(
      `INSERT INTO customer_profiles (user_id, legal_name, email, phone, date_of_birth, id_number_enc, id_number_last4, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET legal_name = excluded.legal_name, email = excluded.email, phone = excluded.phone,
         date_of_birth = excluded.date_of_birth, id_number_enc = excluded.id_number_enc, id_number_last4 = excluded.id_number_last4,
         updated_at = excluded.updated_at`
    ).bind(actor.id, input.legalName, input.email.toLowerCase(), input.phone, input.dateOfBirth, encrypted, input.idNumber.slice(-4), at),
    // Never the values themselves: only that the profile changed.
    auditStatement(c, { action: 'customer.profile_saved', resourceType: 'user', resourceId: actor.id, outcome: 'success' }),
  ])
  const easyclaimId = await ensureEasyclaimId(c.env.DB, actor.id)
  return { ok: true, value: { easyclaimId, profile: toProfile((await loadProfile(c.env.DB, actor.id)) as ProfileRow) } }
}

export async function hasProfile(db: D1Database, userId: string): Promise<boolean> {
  return (await db.prepare('SELECT 1 FROM customer_profiles WHERE user_id = ?').bind(userId).first()) !== null
}

// ------------------------------------------------------------------ requirements

export interface RequirementDto {
  key: string
  label: string
  required: boolean
}

export async function requirementsFor(db: D1Database, tenantId: string): Promise<RequirementDto[]> {
  const { results } = await db
    .prepare('SELECT doc_key, label, required FROM tenant_document_requirements WHERE tenant_id = ? ORDER BY sort_order, doc_key')
    .bind(tenantId)
    .all<{ doc_key: string; label: string; required: number }>()
  return results.map((r) => ({ key: r.doc_key, label: r.label, required: r.required === 1 }))
}

/** Replaces this insurer's list (max 10 items). Existing uploads for removed keys simply stop counting. */
export async function setRequirements(c: C, tenantId: string, items: RequirementDto[]): Promise<RequirementDto[]> {
  const db = c.env.DB
  await db.batch([
    db.prepare('DELETE FROM tenant_document_requirements WHERE tenant_id = ?').bind(tenantId),
    ...items.map((it, i) =>
      db
        .prepare('INSERT INTO tenant_document_requirements (tenant_id, doc_key, label, required, sort_order) VALUES (?, ?, ?, ?, ?)')
        .bind(tenantId, it.key, it.label, it.required ? 1 : 0, i + 1)
    ),
    auditStatement(c, {
      action: 'tenant.requirements_changed',
      resourceType: 'tenant',
      resourceId: tenantId,
      outcome: 'success',
      details: { items: items.length, required: items.filter((i) => i.required).length },
    }),
  ])
  return requirementsFor(db, tenantId)
}

/** Default list for a newly approved insurer (same as the migration's seed). */
export function defaultRequirementStatements(db: D1Database, tenantId: string): D1PreparedStatement[] {
  return [
    ['id_document', 'ID document (green book or smart card)', 1],
    ['proof_of_address', 'Proof of address (not older than 3 months)', 2],
    ['policy_schedule', 'Policy schedule', 3],
  ].map(([key, label, order]) =>
    db
      .prepare(
        `INSERT OR IGNORE INTO tenant_document_requirements (tenant_id, doc_key, label, required, sort_order)
         SELECT ?, ?, ?, 1, ? WHERE EXISTS (SELECT 1 FROM tenants WHERE id = ?)`
      )
      .bind(tenantId, key, label, order, tenantId)
  )
}

// ------------------------------------------------------------------ documents on a request

export interface RequestDocumentDto {
  key: string
  label: string
  required: boolean
  uploaded: boolean
  fileName: string | null
  sizeBytes: number | null
  sha256: string | null
  uploadedAt: string | null
  verified: boolean
}

interface DocRow {
  doc_key: string
  display_name: string
  size_bytes: number
  sha256: string
  uploaded_at: string
  verified: number
  storage_key: string
  mime_type: string
}

/** Requirement checklist of a request: every required item plus any extra uploads. */
export async function checklist(db: D1Database, requestId: string, tenantId: string): Promise<{ items: RequestDocumentDto[]; complete: boolean }> {
  const reqs = await requirementsFor(db, tenantId)
  const { results } = await db.prepare('SELECT * FROM request_documents WHERE request_id = ?').bind(requestId).all<DocRow>()
  const byKey = new Map(results.map((d) => [d.doc_key, d]))
  const items: RequestDocumentDto[] = reqs.map((r) => {
    const d = byKey.get(r.key)
    return {
      key: r.key,
      label: r.label,
      required: r.required,
      uploaded: !!d,
      fileName: d?.display_name ?? null,
      sizeBytes: d?.size_bytes ?? null,
      sha256: d?.sha256 ?? null,
      uploadedAt: d?.uploaded_at ?? null,
      verified: d?.verified === 1,
    }
  })
  const complete = items.filter((i) => i.required).every((i) => i.uploaded && i.verified)
  return { items, complete }
}

/**
 * Checklists for many requests at once (list views): requirements once per tenant and every uploaded
 * document in one query, instead of two queries per row.
 */
export async function checklistMany(
  db: D1Database,
  requests: { id: string; tenantId: string }[]
): Promise<Map<string, { items: RequestDocumentDto[]; complete: boolean }>> {
  const out = new Map<string, { items: RequestDocumentDto[]; complete: boolean }>()
  if (requests.length === 0) return out
  const tenants = [...new Set(requests.map((r) => r.tenantId))]
  const reqByTenant = new Map<string, RequirementDto[]>()
  await Promise.all(tenants.map(async (t) => reqByTenant.set(t, await requirementsFor(db, t))))
  const docs = new Map<string, Map<string, DocRow>>()
  // D1 caps bound parameters per statement; chunk the IN list.
  for (let i = 0; i < requests.length; i += 90) {
    const chunk = requests.slice(i, i + 90).map((r) => r.id)
    const { results } = await db
      .prepare(`SELECT * FROM request_documents WHERE request_id IN (${chunk.map(() => '?').join(',')})`)
      .bind(...chunk)
      .all<DocRow & { request_id: string }>()
    for (const d of results) {
      const m = docs.get(d.request_id) ?? new Map<string, DocRow>()
      m.set(d.doc_key, d)
      docs.set(d.request_id, m)
    }
  }
  for (const r of requests) {
    const byKey = docs.get(r.id) ?? new Map<string, DocRow>()
    const items: RequestDocumentDto[] = (reqByTenant.get(r.tenantId) ?? []).map((q) => {
      const d = byKey.get(q.key)
      return {
        key: q.key,
        label: q.label,
        required: q.required,
        uploaded: !!d,
        fileName: d?.display_name ?? null,
        sizeBytes: d?.size_bytes ?? null,
        sha256: d?.sha256 ?? null,
        uploadedAt: d?.uploaded_at ?? null,
        verified: d?.verified === 1,
      }
    })
    out.set(r.id, { items, complete: items.filter((i) => i.required).every((i) => i.uploaded && i.verified) })
  }
  return out
}

interface RequestRow {
  id: string
  user_id: string
  tenant_id: string
  policy_number: string
  status: string
}

async function ownRequest(db: D1Database, userId: string, requestId: string) {
  return db
    .prepare('SELECT id, user_id, tenant_id, policy_number, status FROM policy_link_requests WHERE id = ? AND user_id = ?')
    .bind(requestId, userId)
    .first<RequestRow>()
}

async function tenantRequest(db: D1Database, tenantId: string, requestId: string) {
  return db
    .prepare('SELECT id, user_id, tenant_id, policy_number, status FROM policy_link_requests WHERE id = ? AND tenant_id = ?')
    .bind(requestId, tenantId)
    .first<RequestRow>()
}

const OPEN = ['pending', 'more_info']

/** Customer uploads (or replaces) one document for an open request. Same file rules as claim evidence. */
export async function uploadRequestDocument(c: C, requestId: string, docKey: string): Promise<Outcome<RequestDocumentDto[]>> {
  const db = c.env.DB
  const actor = c.get('actor')
  const req = await ownRequest(db, actor.id, requestId)
  if (!req) return { ok: false, status: 404, error: 'not_found' }
  if (!OPEN.includes(req.status)) return { ok: false, status: 409, error: 'request_closed' }
  const reqs = await requirementsFor(db, req.tenant_id)
  const requirement = reqs.find((r) => r.key === docKey)
  if (!requirement) return { ok: false, status: 404, error: 'unknown_document' }
  if (!c.env.EVIDENCE_BUCKET) return { ok: false, status: 503, error: 'storage_unavailable' }

  let form: Record<string, string | File>
  try {
    form = await c.req.parseBody()
  } catch {
    return { ok: false, status: 400, error: 'invalid_upload' }
  }
  const file = form['file']
  if (!(file instanceof File)) return { ok: false, status: 400, error: 'file_required' }
  const reject = async (reason: string, status: 400 | 409 | 413 | 415 | 429, error: string) => {
    await writeAuditEvent(c, { action: 'onboarding.document_rejected', resourceType: 'policy_link_request', resourceId: requestId, outcome: 'denied', details: { reason, docKey } })
    return { ok: false as const, status, error }
  }
  if (file.size <= 0 || file.size > MAX_EVIDENCE_BYTES) return reject('size', 413, 'file_too_large')
  if (!isAllowedEvidenceType(file.type)) return reject('unsupported_type', 415, 'unsupported_file_type')
  const bytes = new Uint8Array(await file.arrayBuffer())
  if (!matchesMagicBytes(bytes, file.type)) return reject('magic_bytes_mismatch', 415, 'unsupported_file_type')

  const sha = await sha256Hex(bytes)
  // Server-chosen key: nothing from the client reaches the storage path.
  const storageKey = `onboarding/${req.tenant_id}/${requestId}/${docKey}`
  await c.env.EVIDENCE_BUCKET.put(storageKey, bytes, { httpMetadata: { contentType: file.type }, customMetadata: { sha256: sha } })
  const at = now()
  await db.batch([
    db
      .prepare(
        `INSERT INTO request_documents (id, request_id, doc_key, storage_key, mime_type, size_bytes, sha256, display_name, uploaded_at, verified)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
         ON CONFLICT(request_id, doc_key) DO UPDATE SET storage_key = excluded.storage_key, mime_type = excluded.mime_type,
           size_bytes = excluded.size_bytes, sha256 = excluded.sha256, display_name = excluded.display_name,
           uploaded_at = excluded.uploaded_at, verified = 0, verified_by = NULL, verified_at = NULL`
      )
      .bind(`rdoc_${crypto.randomUUID()}`, requestId, docKey, storageKey, file.type, bytes.length, sha, sanitizeFilename(file.name), at),
    db.prepare('UPDATE policy_link_requests SET updated_at = ? WHERE id = ?').bind(at, requestId),
    auditStatement(c, { action: 'onboarding.document_uploaded', resourceType: 'policy_link_request', resourceId: requestId, outcome: 'success', details: { docKey, sha256: sha } }),
  ])
  return { ok: true, value: (await checklist(db, requestId, req.tenant_id)).items }
}

/** Customer answers a "more information" request: back to the insurer's pending queue. */
export async function resubmitRequest(c: C, requestId: string): Promise<Outcome<true>> {
  const db = c.env.DB
  const actor = c.get('actor')
  const res = await db.batch([
    db
      .prepare(`UPDATE policy_link_requests SET status = 'pending', updated_at = ? WHERE id = ? AND user_id = ? AND status = 'more_info'`)
      .bind(now(), requestId, actor.id),
    auditStatement(c, { action: 'cover.link_resubmitted', resourceType: 'policy_link_request', resourceId: requestId, outcome: 'success' }, { onlyIfPreviousChanged: true }),
  ])
  if (res[0].meta.changes === 1) return { ok: true, value: true }
  return (await ownRequest(db, actor.id, requestId)) ? { ok: false, status: 409, error: 'not_waiting_for_you' } : { ok: false, status: 404, error: 'not_found' }
}

// ------------------------------------------------------------------ insurer admin

export interface ClientCardDto {
  easyclaimId: string | null
  displayName: string
  username: string
  profile: CustomerProfileDto | null
}

async function clientCard(db: D1Database, userId: string): Promise<ClientCardDto> {
  const u = await db.prepare('SELECT username, display_name, easyclaim_id FROM users WHERE id = ?').bind(userId).first<{ username: string; display_name: string; easyclaim_id: string | null }>()
  const p = await loadProfile(db, userId)
  return { easyclaimId: u?.easyclaim_id ?? null, displayName: u?.display_name ?? '', username: u?.username ?? '', profile: p ? toProfile(p) : null }
}

export async function requestDetail(c: C, tenantId: string, requestId: string) {
  const db = c.env.DB
  const req = await tenantRequest(db, tenantId, requestId)
  if (!req) return null
  const row = await db
    .prepare('SELECT status, info_message, decision_reason, created_at, updated_at, policy_id FROM policy_link_requests WHERE id = ?')
    .bind(requestId)
    .first<{ status: string; info_message: string | null; decision_reason: string | null; created_at: string; updated_at: string | null; policy_id: string | null }>()
  const docs = await checklist(db, requestId, tenantId)
  const documentsDone = docs.complete && (await hasProfile(db, req.user_id)) && req.status === 'pending'
  const consent = await latestConsent(c, 'policy_link', requestId)
  return {
    id: req.id,
    policyNumber: req.policy_number,
    status: row!.status,
    infoMessage: row!.info_message,
    decisionReason: row!.decision_reason,
    policyId: row!.policy_id,
    createdAt: row!.created_at,
    updatedAt: row!.updated_at,
    client: await clientCard(db, req.user_id),
    documents: docs.items,
    // Step 1: every required document checked → the consent form can be sent.
    readyForConsent: documentsDone && (consent === null || !['pending', 'signed'].includes(consent.status)),
    // POPIA consent / mandate form for this request (null until sent).
    consent,
    // Step 2: documents checked AND the customer signed → Approve.
    readyToApprove: documentsDone && consent?.status === 'signed',
  }
}

/** Full ID number for this request's client. Every reveal is audited with who and why-context (request id). */
export async function revealIdNumber(c: C, tenantId: string, requestId: string): Promise<Outcome<{ idNumber: string }>> {
  const db = c.env.DB
  const req = await tenantRequest(db, tenantId, requestId)
  if (!req) return { ok: false, status: 404, error: 'not_found' }
  const p = await loadProfile(db, req.user_id)
  if (!p) return { ok: false, status: 404, error: 'no_profile' }
  const idNumber = await decryptField(c.env.PII_KEY, p.id_number_enc)
  if (!idNumber) return { ok: false, status: 503, error: 'pii_unavailable' }
  await writeAuditEvent(c, { action: 'onboarding.id_number_revealed', resourceType: 'policy_link_request', resourceId: requestId, outcome: 'success' })
  return { ok: true, value: { idNumber } }
}

/** The document bytes for the insurer, audited per access. */
export async function openDocument(c: C, tenantId: string, requestId: string, docKey: string): Promise<Response> {
  const db = c.env.DB
  const req = await tenantRequest(db, tenantId, requestId)
  const doc = req ? await db.prepare('SELECT * FROM request_documents WHERE request_id = ? AND doc_key = ?').bind(requestId, docKey).first<DocRow>() : null
  if (!req || !doc) return c.json({ error: 'not_found' }, 404)
  if (!c.env.EVIDENCE_BUCKET) return c.json({ error: 'storage_unavailable' }, 503)
  const obj = await c.env.EVIDENCE_BUCKET.get(doc.storage_key)
  if (!obj) return c.json({ error: 'not_found' }, 404)
  await writeAuditEvent(c, { action: 'onboarding.document_accessed', resourceType: 'policy_link_request', resourceId: requestId, outcome: 'success', details: { docKey } })
  return new Response(obj.body, {
    headers: {
      'Content-Type': doc.mime_type,
      'Content-Disposition': `inline; filename="${doc.display_name}"`,
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      'X-Document-SHA256': doc.sha256,
    },
  })
}

export async function setDocumentVerified(c: C, tenantId: string, requestId: string, docKey: string, verified: boolean): Promise<Outcome<RequestDocumentDto[]>> {
  const db = c.env.DB
  const req = await tenantRequest(db, tenantId, requestId)
  if (!req) return { ok: false, status: 404, error: 'not_found' }
  if (req.status !== 'pending') return { ok: false, status: 409, error: 'not_pending' }
  const res = await db.batch([
    db
      .prepare('UPDATE request_documents SET verified = ?, verified_by = ?, verified_at = ? WHERE request_id = ? AND doc_key = ?')
      .bind(verified ? 1 : 0, verified ? c.get('actor').id : null, verified ? now() : null, requestId, docKey),
    auditStatement(
      c,
      { action: verified ? 'onboarding.document_verified' : 'onboarding.document_unverified', resourceType: 'policy_link_request', resourceId: requestId, outcome: 'success', details: { docKey } },
      { onlyIfPreviousChanged: true }
    ),
  ])
  if (res[0].meta.changes !== 1) return { ok: false, status: 404, error: 'document_not_uploaded' }
  return { ok: true, value: (await checklist(db, requestId, tenantId)).items }
}

export async function requestMoreInfo(c: C, tenantId: string, requestId: string, message: string): Promise<Outcome<true>> {
  const db = c.env.DB
  const res = await db.batch([
    db
      .prepare(`UPDATE policy_link_requests SET status = 'more_info', info_message = ?, updated_at = ? WHERE id = ? AND tenant_id = ? AND status = 'pending'`)
      .bind(message, now(), requestId, tenantId),
    auditStatement(c, { action: 'policy.link_more_info', resourceType: 'policy_link_request', resourceId: requestId, outcome: 'success' }, { onlyIfPreviousChanged: true }),
  ])
  if (res[0].meta.changes === 1) return { ok: true, value: true }
  return (await tenantRequest(db, tenantId, requestId)) ? { ok: false, status: 409, error: 'not_pending' } : { ok: false, status: 404, error: 'not_found' }
}

/** Approval gate used by approvePolicyLink: profile present and every required document uploaded and checked. */
export async function readyToApprove(db: D1Database, tenantId: string, requestId: string): Promise<boolean> {
  const req = await tenantRequest(db, tenantId, requestId)
  if (!req) return false
  return (await hasProfile(db, req.user_id)) && (await checklist(db, requestId, tenantId)).complete
}

/**
 * Exact lookup by EasyClaim ID. Any insurer admin can confirm who an ID belongs to (name only), but
 * details and history are shown only for customers who have a request or policy with this insurer.
 */
export async function findCustomer(c: C, tenantId: string, easyclaimId: string) {
  const db = c.env.DB
  const u = await db.prepare(`SELECT id FROM users WHERE easyclaim_id = ? AND role = 'CUSTOMER'`).bind(easyclaimId).first<{ id: string }>()
  await writeAuditEvent(c, { action: 'tenant.customer_lookup', resourceType: 'tenant', resourceId: tenantId, outcome: u ? 'success' : 'failure' })
  if (!u) return null
  const { results: requests } = await db
    .prepare('SELECT id, policy_number, status, created_at FROM policy_link_requests WHERE user_id = ? AND tenant_id = ? ORDER BY created_at DESC')
    .bind(u.id, tenantId)
    .all<{ id: string; policy_number: string; status: string; created_at: string }>()
  const { results: policies } = await db
    .prepare('SELECT id, plan_name, status, policy_number FROM policies WHERE user_id = ? AND tenant_id = ? ORDER BY id')
    .bind(u.id, tenantId)
    .all<{ id: string; plan_name: string; status: string; policy_number: string | null }>()
  const related = requests.length > 0 || policies.length > 0
  const card = await clientCard(db, u.id)
  return {
    easyclaimId,
    displayName: card.displayName,
    related,
    client: related ? card : null,
    requests: requests.map((r) => ({ id: r.id, policyNumber: r.policy_number, status: r.status, createdAt: r.created_at })),
    policies: policies.map((p) => ({ id: p.id, planName: p.plan_name, status: p.status, policyNumber: p.policy_number })),
  }
}

export { ALLOWED_EVIDENCE_TYPES }
