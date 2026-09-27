/**
 * Insurer onboarding and policy linking (migration 0011, docs/admin/ROLE_MATRIX.md).
 *
 * Two request → decision workflows with the same shape:
 *   insurer_applications   public applicant → SUPERADMIN approves (creates tenant + first INSURER_ADMIN) or rejects
 *   policy_link_requests   CUSTOMER → that insurer's INSURER_ADMIN approves (creates the policy row) or rejects
 *
 * Every decision is ONE D1 batch whose writes are conditional on the row still being `pending`, with the
 * audit row gated on the decision UPDATE (`auditStatement(..., { onlyIfPreviousChanged })`). A second or
 * concurrent decision therefore changes nothing and records nothing. Callers (thin handlers in
 * endpoints/*.ts) pass the scope from the verified actor; nothing here reads the request body for scope.
 */
import type { Context } from 'hono'
import type { AppEnv } from '../types'
import { auditStatement } from '../security/audit'
import { hashPassword } from '../security/password'
import { sha256Hex } from '../security/ledger'
import { isSigned } from '../consent/service'
import { checklist, checklistMany, defaultRequirementStatements, hasProfile, readyToApprove, type RequestDocumentDto } from './customerOnboarding'

type C = Context<AppEnv>
const now = () => new Date().toISOString()

/** Cap on open applications, so the public form cannot fill the table. */
export const MAX_PENDING_APPLICATIONS = 200
/** Per address: at most this many applications in 24 hours (the raw IP is never stored, only its hash). */
export const APPLICATIONS_PER_IP_PER_DAY = 3

// ------------------------------------------------------------------ DTOs

export interface InsurerApplicationDto {
  id: string
  companyName: string
  fspNumber: string
  contactEmail: string
  adminUsername: string
  adminDisplayName: string
  status: 'pending' | 'approved' | 'rejected'
  tenantId: string | null
  decisionReason: string | null
  decidedAt: string | null
  createdAt: string
}

export interface PolicyLinkRequestDto {
  id: string
  tenantId: string
  insurerName: string | null
  policyNumber: string
  status: 'pending' | 'more_info' | 'approved' | 'rejected'
  policyId: string | null
  /** The insurer's question when status is more_info. */
  infoMessage: string | null
  /** Required-document checklist (customer view: to know what to upload; insurer view: what is checked). */
  documents?: RequestDocumentDto[]
  documentsComplete?: boolean
  decisionReason: string | null
  decidedAt: string | null
  createdAt: string
  /** Latest POPIA consent form status (null = not sent yet) and when the customer first opened it. */
  consentStatus: 'pending' | 'signed' | 'declined' | 'withdrawn' | 'superseded' | null
  consentViewedAt: string | null
  /** Only in the insurer's view: who asked (display name and username; no identity numbers exist). */
  customer?: { displayName: string; username: string; easyclaimId: string | null }
}

interface ApplicationRow {
  id: string
  company_name: string
  fsp_number: string
  contact_email: string
  admin_username: string
  admin_display_name: string
  status: InsurerApplicationDto['status']
  tenant_id: string | null
  decision_reason: string | null
  decided_at: string | null
  created_at: string
}

const toApplication = (r: ApplicationRow): InsurerApplicationDto => ({
  id: r.id,
  companyName: r.company_name,
  fspNumber: r.fsp_number,
  contactEmail: r.contact_email,
  adminUsername: r.admin_username,
  adminDisplayName: r.admin_display_name,
  status: r.status,
  tenantId: r.tenant_id,
  decisionReason: r.decision_reason,
  decidedAt: r.decided_at,
  createdAt: r.created_at,
})

const APPLICATION_COLUMNS =
  'id, company_name, fsp_number, contact_email, admin_username, admin_display_name, status, tenant_id, decision_reason, decided_at, created_at'

export type Outcome<T> = { ok: true; value: T } | { ok: false; status: 400 | 404 | 409 | 413 | 415 | 429 | 503; error: string }

// ------------------------------------------------------------------ insurer applications

export async function submitApplication(
  c: C,
  input: { companyName: string; fspNumber: string; contactEmail: string; adminUsername: string; adminDisplayName: string; password: string }
): Promise<Outcome<InsurerApplicationDto>> {
  const db = c.env.DB
  const username = input.adminUsername.toLowerCase()
  const pending = await db.prepare(`SELECT count(*) AS n FROM insurer_applications WHERE status = 'pending'`).first<{ n: number }>()
  if ((pending?.n ?? 0) >= MAX_PENDING_APPLICATIONS) return { ok: false, status: 429, error: 'applications_paused' }
  const ipHash = await sha256Hex(`easyclaim-app|${c.req.header('cf-connecting-ip') ?? 'unknown'}`)
  const fromIp = await db
    .prepare('SELECT count(*) AS n FROM insurer_applications WHERE ip_hash = ? AND created_at >= ?')
    .bind(ipHash, new Date(Date.now() - 86_400_000).toISOString())
    .first<{ n: number }>()
  if ((fromIp?.n ?? 0) >= APPLICATIONS_PER_IP_PER_DAY) return { ok: false, status: 429, error: 'too_many_applications' }
  if (await db.prepare('SELECT 1 FROM users WHERE username = ?').bind(username).first()) return { ok: false, status: 409, error: 'username_taken' }

  const row: ApplicationRow = {
    id: `app_${crypto.randomUUID()}`,
    company_name: input.companyName,
    fsp_number: input.fspNumber,
    contact_email: input.contactEmail.toLowerCase(),
    admin_username: username,
    admin_display_name: input.adminDisplayName,
    status: 'pending',
    tenant_id: null,
    decision_reason: null,
    decided_at: null,
    created_at: now(),
  }
  const insert = db
    .prepare(
      `INSERT INTO insurer_applications (${APPLICATION_COLUMNS}, admin_password_hash, ip_hash) VALUES (?, ?, ?, ?, ?, ?, 'pending', NULL, NULL, NULL, ?, ?, ?)`
    )
    .bind(row.id, row.company_name, row.fsp_number, row.contact_email, row.admin_username, row.admin_display_name, row.created_at, await hashPassword(input.password), ipHash)
  try {
    await db.batch([
      insert,
      auditStatement(c, { action: 'onboarding.application_submitted', resourceType: 'insurer_application', resourceId: row.id, outcome: 'success' }),
    ])
  } catch (err) {
    // The partial unique indexes allow one pending application per username and per FSP number.
    if (String(err).includes('UNIQUE')) return { ok: false, status: 409, error: 'application_pending' }
    throw err
  }
  return { ok: true, value: toApplication(row) }
}

export async function listApplications(db: D1Database, status?: InsurerApplicationDto['status']): Promise<InsurerApplicationDto[]> {
  const { results } = await db
    .prepare(`SELECT ${APPLICATION_COLUMNS} FROM insurer_applications WHERE (? IS NULL OR status = ?) ORDER BY created_at DESC LIMIT 200`)
    .bind(status ?? null, status ?? null)
    .all<ApplicationRow>()
  return results.map(toApplication)
}

async function loadApplication(db: D1Database, id: string) {
  return db.prepare(`SELECT ${APPLICATION_COLUMNS} FROM insurer_applications WHERE id = ?`).bind(id).first<ApplicationRow>()
}

/**
 * Approve: creates the tenant (named after the company) and the applicant's INSURER_ADMIN account with the
 * password hash they chose, then marks the application approved and clears the stored hash. All or nothing.
 */
export async function approveApplication(c: C, applicationId: string, tenantId: string): Promise<Outcome<InsurerApplicationDto>> {
  const db = c.env.DB
  const app = await loadApplication(db, applicationId)
  if (!app) return { ok: false, status: 404, error: 'not_found' }
  if (app.status !== 'pending') return { ok: false, status: 409, error: 'already_decided' }
  if (await db.prepare('SELECT 1 FROM tenants WHERE id = ?').bind(tenantId).first()) return { ok: false, status: 409, error: 'tenant_exists' }
  if (await db.prepare('SELECT 1 FROM users WHERE username = ?').bind(app.admin_username).first()) {
    return { ok: false, status: 409, error: 'username_taken' }
  }

  const actor = c.get('actor')
  const at = now()
  const userId = `usr_${crypto.randomUUID()}`
  const stillPending = `EXISTS (SELECT 1 FROM insurer_applications WHERE id = ? AND status = 'pending')`
  try {
    // Each audit row directly follows the write it records and is gated on it (changes() = 1).
    await db.batch([
      db.prepare(`INSERT INTO tenants (id, name) SELECT ?, ? WHERE ${stillPending}`).bind(tenantId, app.company_name, applicationId),
      auditStatement(c, { action: 'admin.tenant_created', resourceType: 'tenant', resourceId: tenantId, outcome: 'success', details: { via: 'application' } }, { onlyIfPreviousChanged: true }),
      // The new insurer starts with the default required-document list (editable in its console).
      ...defaultRequirementStatements(db, tenantId).map((st) => st),
      db
        .prepare(
          `INSERT INTO users (id, username, password_hash, role, tenant_id, display_name, status, created_at, created_by)
           SELECT ?, admin_username, admin_password_hash, 'INSURER_ADMIN', ?, admin_display_name, 'active', ?, ?
           FROM insurer_applications WHERE id = ? AND status = 'pending'`
        )
        .bind(userId, tenantId, at, actor.id, applicationId),
      auditStatement(c, { action: 'admin.user_created', resourceType: 'user', resourceId: userId, outcome: 'success', details: { role: 'INSURER_ADMIN', tenantId } }, { onlyIfPreviousChanged: true }),
      db
        .prepare(
          `UPDATE insurer_applications SET status = 'approved', tenant_id = ?, decided_by = ?, decided_at = ?, admin_password_hash = ''
           WHERE id = ? AND status = 'pending'`
        )
        .bind(tenantId, actor.id, at, applicationId),
      auditStatement(
        c,
        { action: 'onboarding.application_approved', resourceType: 'insurer_application', resourceId: applicationId, outcome: 'success', details: { tenantId, userId } },
        { onlyIfPreviousChanged: true }
      ),
    ])
  } catch (err) {
    if (String(err).includes('UNIQUE') || String(err).includes('PRIMARY')) return { ok: false, status: 409, error: 'conflict' }
    throw err
  }
  const after = await loadApplication(db, applicationId)
  if (!after || after.status !== 'approved') return { ok: false, status: 409, error: 'already_decided' }
  return { ok: true, value: toApplication(after) }
}

export async function rejectApplication(c: C, applicationId: string, reason: string): Promise<Outcome<InsurerApplicationDto>> {
  const db = c.env.DB
  const app = await loadApplication(db, applicationId)
  if (!app) return { ok: false, status: 404, error: 'not_found' }
  if (app.status !== 'pending') return { ok: false, status: 409, error: 'already_decided' }
  const actor = c.get('actor')
  const res = await db.batch([
    db
      .prepare(
        `UPDATE insurer_applications SET status = 'rejected', decision_reason = ?, decided_by = ?, decided_at = ?, admin_password_hash = ''
         WHERE id = ? AND status = 'pending'`
      )
      .bind(reason, actor.id, now(), applicationId),
    auditStatement(
      c,
      { action: 'onboarding.application_rejected', resourceType: 'insurer_application', resourceId: applicationId, outcome: 'success' },
      { onlyIfPreviousChanged: true }
    ),
  ])
  if (res[0].meta.changes !== 1) return { ok: false, status: 409, error: 'already_decided' }
  return { ok: true, value: toApplication((await loadApplication(db, applicationId)) as ApplicationRow) }
}

// ------------------------------------------------------------------ policy link requests

interface LinkRow {
  id: string
  tenant_id: string
  insurer_name: string | null
  policy_number: string
  status: PolicyLinkRequestDto['status']
  policy_id: string | null
  info_message: string | null
  decision_reason: string | null
  decided_at: string | null
  created_at: string
  display_name?: string
  username?: string
  easyclaim_id?: string | null
  consent_status?: string | null
  consent_viewed_at?: string | null
}

const toLink = (r: LinkRow, withCustomer: boolean): PolicyLinkRequestDto => ({
  id: r.id,
  tenantId: r.tenant_id,
  insurerName: r.insurer_name,
  policyNumber: r.policy_number,
  status: r.status,
  policyId: r.policy_id,
  infoMessage: r.info_message,
  decisionReason: r.decision_reason,
  decidedAt: r.decided_at,
  createdAt: r.created_at,
  consentStatus: (r.consent_status ?? null) as PolicyLinkRequestDto['consentStatus'],
  consentViewedAt: r.consent_viewed_at ?? null,
  ...(withCustomer ? { customer: { displayName: r.display_name ?? '', username: r.username ?? '', easyclaimId: r.easyclaim_id ?? null } } : {}),
})

const LINK_SELECT = `SELECT r.id, r.tenant_id, t.name AS insurer_name, r.policy_number, r.status, r.policy_id, r.info_message, r.decision_reason,
  r.decided_at, r.created_at, u.display_name, u.username, u.easyclaim_id,
  (SELECT k.status FROM consents k WHERE k.subject_type = 'policy_link' AND k.subject_id = r.id ORDER BY k.requested_at DESC, k.rowid DESC LIMIT 1) AS consent_status,
  (SELECT k.viewed_at FROM consents k WHERE k.subject_type = 'policy_link' AND k.subject_id = r.id ORDER BY k.requested_at DESC, k.rowid DESC LIMIT 1) AS consent_viewed_at
  FROM policy_link_requests r LEFT JOIN tenants t ON t.id = r.tenant_id LEFT JOIN users u ON u.id = r.user_id`

/** Insurers a customer can link a policy with: every tenant (id and name only). */
async function withDocuments(db: D1Database, dto: PolicyLinkRequestDto): Promise<PolicyLinkRequestDto> {
  const docs = await checklist(db, dto.id, dto.tenantId)
  return { ...dto, documents: docs.items, documentsComplete: docs.complete }
}

async function withDocumentsMany(db: D1Database, dtos: PolicyLinkRequestDto[]): Promise<PolicyLinkRequestDto[]> {
  const lists = await checklistMany(db, dtos.map((d) => ({ id: d.id, tenantId: d.tenantId })))
  return dtos.map((d) => ({ ...d, documents: lists.get(d.id)?.items ?? [], documentsComplete: lists.get(d.id)?.complete ?? false }))
}

export async function listInsurers(db: D1Database) {
  const { results } = await db.prepare('SELECT id, name FROM tenants ORDER BY name').all<{ id: string; name: string }>()
  return results
}

export async function requestPolicyLink(c: C, tenantId: string, policyNumber: string): Promise<Outcome<PolicyLinkRequestDto>> {
  const db = c.env.DB
  const actor = c.get('actor')
  const number = policyNumber.toUpperCase()
  // Insurers need to know who is asking: the customer's details come first (PUT /covers/profile).
  if (!(await hasProfile(db, actor.id))) return { ok: false, status: 409, error: 'profile_incomplete' }
  if (!(await db.prepare('SELECT 1 FROM tenants WHERE id = ?').bind(tenantId).first())) return { ok: false, status: 404, error: 'unknown_insurer' }
  // A policy number that is already linked cannot be requested again (by anyone).
  if (await db.prepare('SELECT 1 FROM policies WHERE tenant_id = ? AND policy_number = ?').bind(tenantId, number).first()) {
    return { ok: false, status: 409, error: 'policy_already_linked' }
  }
  const id = `plr_${crypto.randomUUID()}`
  const at = now()
  try {
    await db.batch([
      db
        .prepare(`INSERT INTO policy_link_requests (id, user_id, tenant_id, policy_number, status, created_at) VALUES (?, ?, ?, ?, 'pending', ?)`)
        .bind(id, actor.id, tenantId, number, at),
      auditStatement(c, { action: 'cover.link_requested', resourceType: 'policy_link_request', resourceId: id, outcome: 'success', details: { tenantId } }),
    ])
  } catch (err) {
    if (String(err).includes('UNIQUE')) return { ok: false, status: 409, error: 'request_pending' }
    throw err
  }
  const row = await db.prepare(`${LINK_SELECT} WHERE r.id = ?`).bind(id).first<LinkRow>()
  return { ok: true, value: await withDocuments(db, toLink(row as LinkRow, false)) }
}

export async function myLinkRequests(db: D1Database, userId: string): Promise<PolicyLinkRequestDto[]> {
  const { results } = await db.prepare(`${LINK_SELECT} WHERE r.user_id = ? ORDER BY r.created_at DESC LIMIT 50`).bind(userId).all<LinkRow>()
  return withDocumentsMany(db, results.map((r) => toLink(r, false)))
}

export async function tenantLinkRequests(db: D1Database, tenantId: string, status?: PolicyLinkRequestDto['status']): Promise<PolicyLinkRequestDto[]> {
  const { results } = await db
    .prepare(`${LINK_SELECT} WHERE r.tenant_id = ? AND (? IS NULL OR r.status = ?) ORDER BY r.created_at DESC LIMIT 200`)
    .bind(tenantId, status ?? null, status ?? null)
    .all<LinkRow>()
  return withDocumentsMany(db, results.map((r) => toLink(r, true)))
}

async function loadTenantLink(db: D1Database, tenantId: string, requestId: string) {
  // Another tenant's request is indistinguishable from a missing one.
  return db.prepare(`${LINK_SELECT} WHERE r.id = ? AND r.tenant_id = ?`).bind(requestId, tenantId).first<LinkRow>()
}

/** Approve: creates the customer's policy (Active) at this insurer and marks the request approved, atomically. */
export async function approvePolicyLink(c: C, tenantId: string, requestId: string, planName: string): Promise<Outcome<PolicyLinkRequestDto>> {
  const db = c.env.DB
  const req = await loadTenantLink(db, tenantId, requestId)
  if (!req) return { ok: false, status: 404, error: 'not_found' }
  if (req.status !== 'pending') return { ok: false, status: 409, error: req.status === 'more_info' ? 'waiting_for_customer' : 'already_decided' }
  // Approval needs the client's details and every required document uploaded and checked by the insurer.
  if (!(await readyToApprove(db, tenantId, requestId))) return { ok: false, status: 409, error: 'documents_incomplete' }
  // POPIA: then the customer must have signed the insurer's consent form (sent after the document check).
  if (!(await isSigned(db, 'policy_link', requestId))) return { ok: false, status: 409, error: 'consent_required' }
  const actor = c.get('actor')
  const at = now()
  const policyId = `pol_${crypto.randomUUID()}`
  try {
    await db.batch([
      db
        .prepare(
          `INSERT INTO policies (id, user_id, plan_name, status, tenant_id, policy_number, created_at)
           SELECT ?, user_id, ?, 'Active', tenant_id, policy_number, ? FROM policy_link_requests
           WHERE id = ? AND tenant_id = ? AND status = 'pending'`
        )
        .bind(policyId, planName, at, requestId, tenantId),
      db
        .prepare(
          `UPDATE policy_link_requests SET status = 'approved', policy_id = ?, decided_by = ?, decided_at = ?
           WHERE id = ? AND tenant_id = ? AND status = 'pending'`
        )
        .bind(policyId, actor.id, at, requestId, tenantId),
      auditStatement(
        c,
        { action: 'policy.link_approved', resourceType: 'policy_link_request', resourceId: requestId, outcome: 'success', details: { policyId } },
        { onlyIfPreviousChanged: true }
      ),
    ])
  } catch (err) {
    if (String(err).includes('UNIQUE')) return { ok: false, status: 409, error: 'policy_already_linked' }
    throw err
  }
  const after = await loadTenantLink(db, tenantId, requestId)
  if (!after || after.status !== 'approved') return { ok: false, status: 409, error: 'already_decided' }
  return { ok: true, value: await withDocuments(db, toLink(after, true)) }
}

export async function rejectPolicyLink(c: C, tenantId: string, requestId: string, reason: string): Promise<Outcome<PolicyLinkRequestDto>> {
  const db = c.env.DB
  const req = await loadTenantLink(db, tenantId, requestId)
  if (!req) return { ok: false, status: 404, error: 'not_found' }
  if (req.status !== 'pending' && req.status !== 'more_info') return { ok: false, status: 409, error: 'already_decided' }
  const res = await db.batch([
    db
      .prepare(
        `UPDATE policy_link_requests SET status = 'rejected', decision_reason = ?, decided_by = ?, decided_at = ?
         WHERE id = ? AND tenant_id = ? AND status IN ('pending', 'more_info')`
      )
      .bind(reason, c.get('actor').id, now(), requestId, tenantId),
    auditStatement(
      c,
      { action: 'policy.link_rejected', resourceType: 'policy_link_request', resourceId: requestId, outcome: 'success' },
      { onlyIfPreviousChanged: true }
    ),
  ])
  if (res[0].meta.changes !== 1) return { ok: false, status: 409, error: 'already_decided' }
  return { ok: true, value: toLink((await loadTenantLink(db, tenantId, requestId)) as LinkRow, true) }
}
