/**
 * Read-only administration metrics (docs/admin/METRICS.md).
 *
 * Every function here is a SELECT against real tables; nothing is estimated, sampled or
 * invented, and nothing is written. Handlers in src/endpoints/admin.ts decide WHO may call
 * which function (requireRole) and WHICH tenant is passed (always the token's tenant for
 * INSURER_ADMIN). This module never reads the request or the actor, so it cannot widen scope.
 *
 * Responses are explicit DTOs. They carry counts, identifiers and state names only: no ID
 * numbers, banking fields, claim narratives, evidence contents, password hashes or audit
 * `details` blobs.
 */
import { CLAIM_STAGES } from '../security/claimStateMachine'
import { ANOMALY_BANDS, type Interpretation } from '../screening/quantumSignal'

// ------------------------------------------------------------------ DTOs

/** Stages in which a claim is finished or not yet lodged; everything else counts as open. */
export const CLOSED_STAGES = ['Draft', 'Paid', 'Withdrawn', 'Expired'] as const

export interface ClaimCounts {
  /** Lodged claims: every stage except Draft. */
  total: number
  /** Lodged claims not in Paid / Withdrawn / Expired. */
  open: number
  /** Count per stage (every lifecycle stage except Draft, zero-filled). */
  byStage: Record<string, number>
}

export interface DecisionMetrics {
  windowDays: number
  approved: number
  rejected: number
  /** approved / (approved + rejected) in the window, 0..1; null when nothing was decided. */
  approvalRate: number | null
  /** Median hours from claim creation to decision, over decisions in the window whose claim has created_at; null if none. */
  medianHoursToDecision: number | null
}

export interface PayoutMetrics {
  windowDays: number
  count: number
  totalCents: number
}

export interface ScreeningMix {
  NORMAL: number
  ELEVATED: number
  HIGH: number
  /** Lodged claims without a stored screening signal. */
  unscreened: number
}

export interface IntegrityMix {
  /** Decisions with an ML-DSA-65 signature recorded. */
  signed: number
  /** Decisions without a signature (recorded before Phase 5 or with signing unavailable). */
  unsigned: number
  /** Results of /decision/verify calls in the window, by status (VALID, TAMPERED, ...). */
  verificationsInWindow: Record<string, number>
}

export interface StaffCounts {
  byRole: Record<string, number>
  active: number
  disabled: number
}

export interface TenantOverview {
  tenant: { id: string; name: string } | null
  generatedAt: string
  claims: ClaimCounts
  decisions: DecisionMetrics
  payouts: PayoutMetrics
  screening: ScreeningMix
  integrity: IntegrityMix
  staff: StaffCounts
  /** Customers' policy-link requests waiting for this insurer's decision. */
  pendingPolicyRequests: number
  /** Live work counters for the insurer admin (see docs/admin/METRICS.md). */
  attention: AttentionCounts
}

export interface AttentionCounts {
  /** Latest POPIA form per subject: sent and not yet opened / opened but not signed / declined / withdrawn. */
  awaitingMandate: number
  mandateOpened: number
  mandateDeclined: number
  consentWithdrawn: number
  /** Claims waiting on the customer (Info Needed) and new claims not yet verified (Submitted). */
  infoNeeded: number
  newClaims: number
}

export interface PlatformTenantSummary {
  id: string
  name: string
  claims: number
  openClaims: number
  staff: number
  activeAdmins: number
  decisionsInWindow: number
  payoutsInWindow: number
}

export interface PlatformOverview {
  generatedAt: string
  windowDays: number
  tenants: number
  usersByRole: Record<string, number>
  claims: ClaimCounts
  decisions: DecisionMetrics
  payouts: PayoutMetrics
  perTenant: PlatformTenantSummary[]
  /** Insurer applications waiting for the platform operator's decision. */
  pendingApplications: number
}

export interface AdminAuditEvent {
  id: string
  occurredAt: string
  /** Null when the actor is outside the viewer's scope (e.g. a customer or platform operator seen by a tenant). */
  actorId: string | null
  actorRole: string | null
  action: string
  resourceType: string
  resourceId: string | null
  outcome: 'success' | 'denied' | 'failure'
  /** claim.stage_changed only: the new stage (for "Claim moved to Screening"). Other details are never exposed. */
  toStage: string | null
}

export interface AuditPage {
  events: AdminAuditEvent[]
  /** Pass as `before` to fetch the next (older) page; null when there are no more rows. */
  nextBefore: string | null
}

export interface PlatformSecurity {
  generatedAt: string
  windowDays: number
  logins: { success: number; denied: number }
  deniedByAction: { action: string; count: number }[]
  failuresByAction: { action: string; count: number }[]
  deniedByTenant: { tenantId: string | null; count: number }[]
  disabledAccounts: number
  recentDenied: AdminAuditEvent[]
  /** Signals that exist but are not recorded in audit_events, so they are not counted here. */
  notMeasured: string[]
}

export interface PlatformIntegrity {
  generatedAt: string
  windowDays: number
  decisions: { total: number; signed: number; unsigned: number; byKeyId: { keyId: string; count: number }[] }
  verificationsInWindow: Record<string, number>
  screening: ScreeningMix & { byExecution: Record<string, number>; byModelVersion: { modelVersion: string; count: number }[] }
}

export interface AuditFilters {
  limit: number
  before?: string
  outcome?: 'success' | 'denied' | 'failure'
  /** Action prefix, e.g. "auth." or "payout.". */
  action?: string
  /** SUPERADMIN only: restrict the platform log to one tenant's scope. */
  tenantId?: string
}

// ------------------------------------------------------------------ helpers

export function sinceIso(windowDays: number, now = Date.now()): string {
  return new Date(now - windowDays * 86_400_000).toISOString()
}

function median(values: number[]): number | null {
  if (values.length === 0) return null
  const s = [...values].sort((a, b) => a - b)
  const mid = Math.floor(s.length / 2)
  const m = s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2
  return Math.round(m * 10) / 10
}

/** `tenant IS NULL` means platform-wide. Each helper binds the tenant twice for `(? IS NULL OR col = ?)`. */
type Scope = string | null

// ------------------------------------------------------------------ building blocks

export async function claimCounts(db: D1Database, tenantId: Scope): Promise<ClaimCounts> {
  const { results } = await db
    .prepare(`SELECT stage, count(*) AS n FROM claims WHERE stage <> 'Draft' AND (? IS NULL OR tenant_id = ?) GROUP BY stage`)
    .bind(tenantId, tenantId)
    .all<{ stage: string; n: number }>()
  const byStage: Record<string, number> = {}
  for (const s of CLAIM_STAGES) if (s !== 'Draft') byStage[s] = 0
  let total = 0
  let open = 0
  for (const r of results) {
    byStage[r.stage] = r.n
    total += r.n
    if (!(CLOSED_STAGES as readonly string[]).includes(r.stage)) open += r.n
  }
  return { total, open, byStage }
}

export async function decisionMetrics(db: D1Database, tenantId: Scope, windowDays: number): Promise<DecisionMetrics> {
  const since = sinceIso(windowDays)
  const { results } = await db
    .prepare(
      `SELECT d.outcome AS outcome, d.decided_at AS decided_at, c.created_at AS created_at
       FROM claim_decisions d JOIN claims c ON c.id = d.claim_id
       WHERE d.decided_at >= ? AND (? IS NULL OR d.tenant_id = ?)
       LIMIT 10000`
    )
    .bind(since, tenantId, tenantId)
    .all<{ outcome: string; decided_at: string; created_at: string | null }>()
  let approved = 0
  let rejected = 0
  const hours: number[] = []
  for (const r of results) {
    if (r.outcome === 'Approved') approved++
    else if (r.outcome === 'Rejected') rejected++
    if (r.created_at) {
      const h = (Date.parse(r.decided_at) - Date.parse(r.created_at)) / 3_600_000
      if (Number.isFinite(h) && h >= 0) hours.push(h)
    }
  }
  const decided = approved + rejected
  return {
    windowDays,
    approved,
    rejected,
    approvalRate: decided === 0 ? null : Math.round((approved / decided) * 1000) / 1000,
    medianHoursToDecision: median(hours),
  }
}

export async function payoutMetrics(db: D1Database, tenantId: Scope, windowDays: number): Promise<PayoutMetrics> {
  const row = await db
    .prepare(`SELECT count(*) AS n, coalesce(sum(amount_cents), 0) AS total FROM payouts WHERE initiated_at >= ? AND (? IS NULL OR tenant_id = ?)`)
    .bind(sinceIso(windowDays), tenantId, tenantId)
    .first<{ n: number; total: number }>()
  return { windowDays, count: row?.n ?? 0, totalCents: row?.total ?? 0 }
}

export async function screeningMix(db: D1Database, tenantId: Scope): Promise<ScreeningMix> {
  const { results } = await db
    .prepare(
      `SELECT s.interpretation AS interpretation, count(*) AS n
       FROM screening_signals s JOIN claims c ON c.id = s.claim_id
       WHERE c.stage <> 'Draft' AND (? IS NULL OR c.tenant_id = ?)
       GROUP BY s.interpretation`
    )
    .bind(tenantId, tenantId)
    .all<{ interpretation: Interpretation; n: number }>()
  const mix: ScreeningMix = { NORMAL: 0, ELEVATED: 0, HIGH: 0, unscreened: 0 }
  let screened = 0
  for (const r of results) {
    const band = ANOMALY_BANDS[r.interpretation]
    if (band) {
      mix[band] += r.n
      screened += r.n
    }
  }
  const lodged = await db
    .prepare(`SELECT count(*) AS n FROM claims WHERE stage <> 'Draft' AND (? IS NULL OR tenant_id = ?)`)
    .bind(tenantId, tenantId)
    .first<{ n: number }>()
  mix.unscreened = Math.max(0, (lodged?.n ?? 0) - screened)
  return mix
}

async function verificationCounts(db: D1Database, tenantId: Scope, windowDays: number): Promise<Record<string, number>> {
  const { results } = await db
    .prepare(
      `SELECT json_extract(a.details, '$.status') AS status, count(*) AS n
       FROM audit_events a
       WHERE a.action = 'decision.integrity_verified' AND a.occurred_at >= ?
         AND (? IS NULL OR a.resource_id IN (SELECT id FROM claim_decisions WHERE tenant_id = ?))
       GROUP BY status`
    )
    .bind(sinceIso(windowDays), tenantId, tenantId)
    .all<{ status: string | null; n: number }>()
  const out: Record<string, number> = {}
  for (const r of results) out[r.status ?? 'UNKNOWN'] = r.n
  return out
}

export async function integrityMix(db: D1Database, tenantId: Scope, windowDays: number): Promise<IntegrityMix> {
  const row = await db
    .prepare(
      `SELECT sum(CASE WHEN integrity_alg IS NOT NULL THEN 1 ELSE 0 END) AS signed,
              sum(CASE WHEN integrity_alg IS NULL THEN 1 ELSE 0 END) AS unsigned
       FROM claim_decisions WHERE (? IS NULL OR tenant_id = ?)`
    )
    .bind(tenantId, tenantId)
    .first<{ signed: number | null; unsigned: number | null }>()
  return {
    signed: row?.signed ?? 0,
    unsigned: row?.unsigned ?? 0,
    verificationsInWindow: await verificationCounts(db, tenantId, windowDays),
  }
}

export async function staffCounts(db: D1Database, tenantId: string): Promise<StaffCounts> {
  const { results } = await db
    .prepare(`SELECT role, status, count(*) AS n FROM users WHERE tenant_id = ? GROUP BY role, status`)
    .bind(tenantId)
    .all<{ role: string; status: string; n: number }>()
  const out: StaffCounts = { byRole: {}, active: 0, disabled: 0 }
  for (const r of results) {
    out.byRole[r.role] = (out.byRole[r.role] ?? 0) + r.n
    if (r.status === 'active') out.active += r.n
    else out.disabled += r.n
  }
  return out
}

// ------------------------------------------------------------------ tenant (INSURER_ADMIN)

export async function tenantOverview(db: D1Database, tenantId: string, windowDays: number): Promise<TenantOverview> {
  const tenant = await db.prepare('SELECT id, name FROM tenants WHERE id = ?').bind(tenantId).first<{ id: string; name: string }>()
  const [claims, decisions, payouts, screening, integrity, staff] = await Promise.all([
    claimCounts(db, tenantId),
    decisionMetrics(db, tenantId, windowDays),
    payoutMetrics(db, tenantId, windowDays),
    screeningMix(db, tenantId),
    integrityMix(db, tenantId, windowDays),
    staffCounts(db, tenantId),
  ])
  const pending = await db
    .prepare(`SELECT count(*) AS n FROM policy_link_requests WHERE tenant_id = ? AND status = 'pending'`)
    .bind(tenantId)
    .first<{ n: number }>()
  return {
    tenant,
    generatedAt: new Date().toISOString(),
    claims,
    decisions,
    payouts,
    screening,
    integrity,
    staff,
    pendingPolicyRequests: pending?.n ?? 0,
    attention: await attentionCounts(db, tenantId, claims.byStage),
  }
}

/** Latest form per subject only, so a re-sent form replaces the declined one in the counts. */
async function attentionCounts(db: D1Database, tenantId: string, byStage: Record<string, number>): Promise<AttentionCounts> {
  const { results } = await db
    .prepare(
      `SELECT CASE WHEN k.status = 'pending' AND k.viewed_at IS NOT NULL THEN 'opened' ELSE k.status END AS s, count(*) AS n
       FROM consents k
       WHERE k.tenant_id = ? AND k.rowid = (SELECT k2.rowid FROM consents k2 WHERE k2.subject_type = k.subject_type AND k2.subject_id = k.subject_id
                                             ORDER BY k2.requested_at DESC, k2.rowid DESC LIMIT 1)
       GROUP BY s`
    )
    .bind(tenantId)
    .all<{ s: string; n: number }>()
  const by = Object.fromEntries(results.map((r) => [r.s, r.n])) as Record<string, number>
  return {
    awaitingMandate: by.pending ?? 0,
    mandateOpened: by.opened ?? 0,
    mandateDeclined: by.declined ?? 0,
    consentWithdrawn: by.withdrawn ?? 0,
    infoNeeded: byStage['Info Needed'] ?? 0,
    newClaims: byStage['Submitted'] ?? 0,
  }
}

// ------------------------------------------------------------------ audit

interface AuditRow {
  id: string
  occurred_at: string
  actor_id: string | null
  actor_role: string | null
  actor_tenant_id: string | null
  action: string
  resource_type: string
  resource_id: string | null
  outcome: AdminAuditEvent['outcome']
  details?: string | null
}

/** For stage changes only: the stage a claim moved to (a fixed state name, never free text). */
function toStageOf(r: AuditRow): string | null {
  if (r.action !== 'claim.stage_changed' || !r.details) return null
  try {
    const to = (JSON.parse(r.details) as { to?: unknown }).to
    return typeof to === 'string' && (CLAIM_STAGES as readonly string[]).includes(to) ? to : null
  } catch {
    return null
  }
}

const AUDIT_COLUMNS = 'id, occurred_at, actor_id, actor_role, actor_tenant_id, action, resource_type, resource_id, outcome, details'

/**
 * A tenant's audit scope: events by the tenant's own staff, plus events on the tenant's claims,
 * decisions, payouts, evidence, policies, accounts and tenant record (whoever the actor was).
 */
const TENANT_SCOPE_SQL = `(
  actor_tenant_id = :t
  OR (resource_type = 'claim' AND resource_id IN (SELECT id FROM claims WHERE tenant_id = :t))
  OR (resource_type = 'claim_decision' AND resource_id IN (SELECT id FROM claim_decisions WHERE tenant_id = :t))
  OR (resource_type = 'payout' AND resource_id IN (SELECT id FROM payouts WHERE tenant_id = :t))
  OR (resource_type = 'evidence' AND resource_id IN (SELECT id FROM evidence WHERE tenant_id = :t))
  OR (resource_type = 'user' AND resource_id IN (SELECT id FROM users WHERE tenant_id = :t))
  OR (resource_type = 'policy' AND resource_id IN (SELECT id FROM policies WHERE tenant_id = :t))
  OR (resource_type = 'tenant' AND resource_id = :t)
  OR (resource_type = 'consent' AND resource_id IN (SELECT id FROM consents WHERE tenant_id = :t))
  OR (resource_type = 'policy_link_request' AND resource_id IN (SELECT id FROM policy_link_requests WHERE tenant_id = :t))
)`
const TENANT_SCOPE_BINDS = (TENANT_SCOPE_SQL.match(/:t/g) ?? []).length

function toAuditEvent(r: AuditRow, viewerTenant: Scope): AdminAuditEvent {
  // A tenant viewer sees its own staff's ids; other actors (customers, platform operators,
  // other tenants) are shown by role only.
  const showActor = viewerTenant === null || r.actor_tenant_id === viewerTenant
  return {
    id: r.id,
    occurredAt: r.occurred_at,
    actorId: showActor ? r.actor_id : null,
    actorRole: r.actor_role,
    action: r.action,
    resourceType: r.resource_type,
    resourceId: r.resource_id,
    outcome: r.outcome,
    toStage: toStageOf(r),
  }
}

/**
 * One page of the audit log, newest first. `viewerTenant` = the INSURER_ADMIN's tenant (scope is
 * forced to it) or null for SUPERADMIN (optionally narrowed by filters.tenantId).
 */
export async function auditPage(db: D1Database, viewerTenant: Scope, filters: AuditFilters): Promise<AuditPage> {
  const scopeTenant = viewerTenant ?? filters.tenantId ?? null
  const where: string[] = []
  const binds: unknown[] = []
  if (scopeTenant !== null) {
    where.push(TENANT_SCOPE_SQL.replaceAll(':t', '?'))
    for (let i = 0; i < TENANT_SCOPE_BINDS; i++) binds.push(scopeTenant)
  }
  if (filters.before) {
    where.push('occurred_at < ?')
    binds.push(filters.before)
  }
  if (filters.outcome) {
    where.push('outcome = ?')
    binds.push(filters.outcome)
  }
  if (filters.action) {
    // Prefix match with LIKE wildcards escaped, so the filter cannot become a pattern.
    where.push("action LIKE ? ESCAPE '\\'")
    binds.push(filters.action.replace(/[\\%_]/g, (m) => `\\${m}`) + '%')
  }
  const sql = `SELECT ${AUDIT_COLUMNS} FROM audit_events ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
               ORDER BY occurred_at DESC, id DESC LIMIT ?`
  binds.push(filters.limit + 1)
  const { results } = await db.prepare(sql).bind(...binds).all<AuditRow>()
  const more = results.length > filters.limit
  const page = results.slice(0, filters.limit)
  return {
    events: page.map((r) => toAuditEvent(r, viewerTenant)),
    nextBefore: more && page.length ? page[page.length - 1].occurred_at : null,
  }
}

// ------------------------------------------------------------------ platform (SUPERADMIN)

export async function platformOverview(db: D1Database, windowDays: number): Promise<PlatformOverview> {
  const since = sinceIso(windowDays)
  const roles = await db.prepare('SELECT role, count(*) AS n FROM users GROUP BY role').all<{ role: string; n: number }>()
  const usersByRole: Record<string, number> = {}
  for (const r of roles.results) usersByRole[r.role] = r.n

  const closed = CLOSED_STAGES.map(() => '?').join(', ')
  const { results: perTenant } = await db
    .prepare(
      `SELECT t.id AS id, t.name AS name,
         (SELECT count(*) FROM claims c WHERE c.tenant_id = t.id AND c.stage <> 'Draft') AS claims,
         (SELECT count(*) FROM claims c WHERE c.tenant_id = t.id AND c.stage NOT IN (${closed})) AS openClaims,
         (SELECT count(*) FROM users u WHERE u.tenant_id = t.id) AS staff,
         (SELECT count(*) FROM users u WHERE u.tenant_id = t.id AND u.role = 'INSURER_ADMIN' AND u.status = 'active') AS activeAdmins,
         (SELECT count(*) FROM claim_decisions d WHERE d.tenant_id = t.id AND d.decided_at >= ?) AS decisionsInWindow,
         (SELECT count(*) FROM payouts p WHERE p.tenant_id = t.id AND p.initiated_at >= ?) AS payoutsInWindow
       FROM tenants t ORDER BY t.name`
    )
    .bind(...CLOSED_STAGES, since, since)
    .all<PlatformTenantSummary>()

  const [claims, decisions, payouts] = await Promise.all([
    claimCounts(db, null),
    decisionMetrics(db, null, windowDays),
    payoutMetrics(db, null, windowDays),
  ])
  const pending = await db.prepare(`SELECT count(*) AS n FROM insurer_applications WHERE status = 'pending'`).first<{ n: number }>()
  return {
    generatedAt: new Date().toISOString(),
    windowDays,
    tenants: perTenant.length,
    usersByRole,
    claims,
    decisions,
    payouts,
    perTenant,
    pendingApplications: pending?.n ?? 0,
  }
}

export async function platformSecurity(db: D1Database, windowDays: number): Promise<PlatformSecurity> {
  const since = sinceIso(windowDays)
  const logins = await db
    .prepare(
      `SELECT sum(CASE WHEN outcome = 'success' THEN 1 ELSE 0 END) AS ok,
              sum(CASE WHEN outcome = 'denied' THEN 1 ELSE 0 END) AS denied
       FROM audit_events WHERE action = 'auth.login' AND occurred_at >= ?`
    )
    .bind(since)
    .first<{ ok: number | null; denied: number | null }>()
  const byAction = async (outcome: 'denied' | 'failure') =>
    (
      await db
        .prepare(
          `SELECT action, count(*) AS count FROM audit_events WHERE outcome = ? AND occurred_at >= ?
           GROUP BY action ORDER BY count DESC, action LIMIT 10`
        )
        .bind(outcome, since)
        .all<{ action: string; count: number }>()
    ).results
  const { results: deniedByTenant } = await db
    .prepare(
      `SELECT actor_tenant_id AS tenantId, count(*) AS count FROM audit_events
       WHERE outcome = 'denied' AND occurred_at >= ? GROUP BY actor_tenant_id ORDER BY count DESC LIMIT 20`
    )
    .bind(since)
    .all<{ tenantId: string | null; count: number }>()
  const disabled = await db.prepare(`SELECT count(*) AS n FROM users WHERE status = 'disabled'`).first<{ n: number }>()
  const recent = await auditPage(db, null, { limit: 20, outcome: 'denied' })
  return {
    generatedAt: new Date().toISOString(),
    windowDays,
    logins: { success: logins?.ok ?? 0, denied: logins?.denied ?? 0 },
    deniedByAction: await byAction('denied'),
    failuresByAction: await byAction('failure'),
    deniedByTenant,
    disabledAccounts: disabled?.n ?? 0,
    recentDenied: recent.events.filter((e) => e.occurredAt >= since),
    notMeasured: ['rejected_bearer_tokens (logged to the Worker console only, not to audit_events)', 'rate_limited_requests (429s are not audited)'],
  }
}

export async function platformIntegrity(db: D1Database, windowDays: number): Promise<PlatformIntegrity> {
  const mix = await integrityMix(db, null, windowDays)
  const { results: byKeyId } = await db
    .prepare(
      `SELECT integrity_key_id AS keyId, count(*) AS count FROM claim_decisions
       WHERE integrity_key_id IS NOT NULL GROUP BY integrity_key_id ORDER BY count DESC`
    )
    .all<{ keyId: string; count: number }>()
  const screening = await screeningMix(db, null)
  const { results: execRows } = await db
    .prepare(`SELECT execution, count(*) AS n FROM screening_signals GROUP BY execution`)
    .all<{ execution: string; n: number }>()
  const byExecution: Record<string, number> = {}
  for (const r of execRows) byExecution[r.execution] = r.n
  const { results: byModelVersion } = await db
    .prepare(`SELECT model_version AS modelVersion, count(*) AS count FROM screening_signals GROUP BY model_version ORDER BY count DESC`)
    .all<{ modelVersion: string; count: number }>()
  return {
    generatedAt: new Date().toISOString(),
    windowDays,
    decisions: { total: mix.signed + mix.unsigned, signed: mix.signed, unsigned: mix.unsigned, byKeyId },
    verificationsInWindow: mix.verificationsInWindow,
    screening: { ...screening, byExecution, byModelVersion },
  }
}
