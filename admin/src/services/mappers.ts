/**
 * Pure mapping functions from raw backend JSON to the admin app's types.
 *
 * Rule: never invent a value. A field the backend did not send (or sent in an unexpected shape)
 * becomes `null`, and an object that is missing its identifying fields makes the mapper return
 * `null` so the UI shows an honest "Not available" instead of a plausible-looking placeholder.
 */
import type {
  Actor,
  AnomalyBand,
  AuditEvent,
  AuditPage,
  ClaimDetail,
  ClaimSummary,
  DecisionInfo,
  DecisionIntegrity,
  EvidenceItem,
  EvidenceVerifyResult,
  IntegrityStatus,
  MessageRef,
  PayoutView,
  PlatformIntegrity,
  PublicKeyInfo,
  RiskSignals,
  Role,
  ScreeningMix,
  Session,
  TenantOverviewSummary,
  Timeline,
  TimelineEntry,
} from '../types'
import { ROLES } from '../types'

type Obj = Record<string, unknown>

export function isObj(v: unknown): v is Obj {
  return typeof v === 'object' && v !== null && !Array.isArray(v)
}

/** Non-empty string or null. */
export function str(v: unknown): string | null {
  return typeof v === 'string' && v.trim() !== '' ? v : null
}

/** Finite number or null (no coercion from strings). */
export function num(v: unknown): number | null {
  return typeof v === 'number' && Number.isFinite(v) ? v : null
}

function numRecord(v: unknown): Record<string, number> {
  const out: Record<string, number> = {}
  if (!isObj(v)) return out
  for (const [k, val] of Object.entries(v)) {
    const n = num(val)
    if (n !== null) out[k] = n
  }
  return out
}

// ------------------------------------------------------------------ auth

export function isRole(v: unknown): v is Role {
  return typeof v === 'string' && (ROLES as readonly string[]).includes(v)
}

export function mapActor(raw: unknown): Actor | null {
  if (!isObj(raw)) return null
  const id = str(raw.id)
  const username = str(raw.username)
  if (!id || !username || !isRole(raw.role)) return null
  return {
    id,
    username,
    role: raw.role,
    tenantId: str(raw.tenantId),
    displayName: str(raw.displayName),
    status: str(raw.status),
  }
}

/** Maps the POST /auth/login body. Returns null unless it carries a token and a valid actor. */
export function mapLoginResponse(raw: unknown, now: number = Date.now()): Session | null {
  if (!isObj(raw)) return null
  const token = str(raw.token)
  const actor = mapActor(raw.actor)
  if (!token || !actor) return null
  const expiresIn = num(raw.expiresIn)
  return { token, actor, expiresAt: expiresIn !== null && expiresIn > 0 ? now + expiresIn * 1000 : null }
}

/** Validates a session read back from storage (it may be stale, edited or from an older build). */
export function parseStoredSession(raw: unknown, now: number = Date.now()): Session | null {
  if (!isObj(raw)) return null
  const token = str(raw.token)
  const actor = mapActor(raw.actor)
  if (!token || !actor) return null
  const expiresAt = num(raw.expiresAt)
  if (expiresAt !== null && expiresAt <= now) return null
  return { token, actor, expiresAt }
}

// ------------------------------------------------------------------ claims

/** One row of GET /claims (snake_case). */
export function mapClaimSummary(raw: unknown): ClaimSummary | null {
  if (!isObj(raw)) return null
  const id = str(raw.id)
  const stage = str(raw.stage)
  if (!id || !stage) return null
  return {
    id,
    policyId: str(raw.policy_id) ?? '',
    tenantId: str(raw.tenant_id),
    stage,
    status: str(raw.status),
    category: str(raw.category),
    claimedAmountCents: num(raw.claimed_amount_cents),
    createdAt: str(raw.created_at),
    updatedAt: str(raw.updated_at),
  }
}

export function mapClaimList(raw: unknown): ClaimSummary[] {
  if (!isObj(raw) || !Array.isArray(raw.claims)) return []
  return raw.claims.map(mapClaimSummary).filter((c): c is ClaimSummary => c !== null)
}

function mapMessageRef(raw: unknown): MessageRef | null {
  if (!isObj(raw)) return null
  const body = str(raw.body)
  if (!body) return null
  return { body, createdAt: str(raw.createdAt) }
}

/** GET /claims/:id. Accepts either the whole body `{claim}` or the claim object itself. */
export function mapClaimDetail(raw: unknown): ClaimDetail | null {
  const c = isObj(raw) && isObj(raw.claim) ? raw.claim : raw
  if (!isObj(c)) return null
  const id = str(c.id)
  const stage = str(c.stage)
  if (!id || !stage) return null
  const dest = isObj(c.payoutDestination) ? c.payoutDestination : null
  const last4 = dest ? str(dest.accountLast4) : null
  return {
    id,
    policyId: str(c.policyId) ?? '',
    planName: str(c.planName),
    tenantId: str(c.tenantId),
    insurerName: str(c.insurerName),
    stage,
    status: str(c.status),
    category: str(c.category),
    causeOfLoss: str(c.causeOfLoss),
    incidentDate: str(c.incidentDate),
    claimedAmountCents: num(c.claimedAmountCents),
    // Only a destination the backend actually reports; no bank or digits are ever filled in.
    payoutDestination: dest && last4 ? { bankName: str(dest.bankName), accountLast4: last4 } : null,
    createdAt: str(c.createdAt),
    updatedAt: str(c.updatedAt),
    infoRequest: mapMessageRef(c.infoRequest),
    appealReason: mapMessageRef(c.appealReason),
  }
}

/** GET /claims/:id/timeline */
export function mapTimeline(raw: unknown): Timeline {
  if (!isObj(raw)) return { currentStage: null, entries: [] }
  const list = Array.isArray(raw.timeline) ? raw.timeline : []
  const entries: TimelineEntry[] = []
  for (const item of list) {
    if (!isObj(item)) continue
    const stage = str(item.stage)
    if (!stage) continue
    entries.push({ stage, completed: item.completed === true, date: str(item.date) })
  }
  return { currentStage: str(raw.currentStage), entries }
}

// ------------------------------------------------------------------ screening

const BANDS: readonly AnomalyBand[] = ['NORMAL', 'ELEVATED', 'HIGH']

function unitInterval(v: unknown): number | null {
  const n = num(v)
  return n !== null && n >= 0 && n <= 1 ? n : null
}

/**
 * GET /claims/:id/risk-signals. Accepts the whole body `{riskSignals}` or the signal itself.
 * Returns null when there is no signal or it does not have the documented shape (no guessed band).
 */
export function mapRiskSignals(raw: unknown): RiskSignals | null {
  const s = isObj(raw) && 'riskSignals' in raw ? raw.riskSignals : raw
  if (!isObj(s)) return null
  const classicalAnomaly = unitInterval(s.classicalAnomaly)
  const quantumAnomaly = unitInterval(s.quantumAnomaly)
  const band = s.anomalyBand
  const rec = s.screeningRecommendation
  const modelVersion = str(s.modelVersion)
  if (
    classicalAnomaly === null ||
    quantumAnomaly === null ||
    typeof band !== 'string' ||
    !(BANDS as readonly string[]).includes(band) ||
    (rec !== 'STANDARD_REVIEW' && rec !== 'REVIEW_REQUIRED') ||
    (s.execution !== 'simulator' && s.execution !== 'hardware') ||
    !modelVersion
  ) {
    return null
  }
  const v = isObj(s.versions) ? s.versions : null
  return {
    classicalAnomaly,
    quantumAnomaly,
    interpretation: str(s.interpretation) ?? band,
    anomalyBand: band as AnomalyBand,
    screeningRecommendation: rec,
    explanation: str(s.explanation) ?? '',
    versions: v
      ? { model: str(v.model), features: str(v.features), kernel: str(v.kernel), screening: str(v.screening) }
      : null,
    signalDigest: str(s.signalDigest),
    modelVersion,
    execution: s.execution,
    computedAt: str(s.computedAt),
    advisory: s.advisory === true,
  }
}

// ------------------------------------------------------------------ decision + integrity

/** GET /claims/:id/decision */
export function mapDecision(raw: unknown): DecisionInfo | null {
  if (!isObj(raw)) return null
  const decision = str(raw.decision)
  if (!decision) return null
  const r = isObj(raw.record) ? raw.record : null
  const id = r ? str(r.id) : null
  return {
    decision,
    record:
      r && id
        ? {
            id,
            decidedAt: str(r.decidedAt),
            decidedByRole: str(r.decidedByRole),
            reason: str(r.reason),
            approvedAmountCents: num(r.approvedAmountCents),
            rulesVersion: str(r.rulesVersion),
            evidenceDigest: str(r.evidenceDigest),
          }
        : null,
  }
}

const INTEGRITY_STATUSES: readonly IntegrityStatus[] = ['VALID', 'TAMPERED', 'UNSIGNED', 'UNKNOWN_KEY', 'UNAVAILABLE', 'NO_DECISION']

/** GET /claims/:id/decision/verify. Returns null when the body has no recognised status. */
export function mapDecisionIntegrity(raw: unknown): DecisionIntegrity | null {
  if (!isObj(raw) || !isObj(raw.integrity)) return null
  const i = raw.integrity
  const status = i.status
  if (typeof status !== 'string' || !(INTEGRITY_STATUSES as readonly string[]).includes(status)) return null
  return {
    claimId: str(raw.claimId),
    decisionId: str(raw.decisionId),
    status: status as IntegrityStatus,
    alg: str(i.alg),
    keyId: str(i.keyId),
    bundleDigest: str(i.bundleDigest),
    recomputedDigest: str(i.recomputedDigest),
  }
}

/** GET /claims/:id/payout */
export function mapPayout(raw: unknown): PayoutView | null {
  if (!isObj(raw)) return null
  const d = isObj(raw.destination) ? raw.destination : null
  const dec = isObj(raw.decision) ? raw.decision : null
  const p = isObj(raw.payout) ? raw.payout : null
  const decId = dec ? str(dec.id) : null
  const payId = p ? str(p.id) : null
  return {
    claimedAmountCents: num(raw.claimedAmountCents),
    destination: d
      ? { bankName: str(d.bankName), accountHolder: str(d.accountHolder), accountLast4: str(d.accountLast4) }
      : null,
    decision:
      dec && decId
        ? {
            id: decId,
            outcome: str(dec.outcome) ?? '',
            approvedAmountCents: num(dec.approvedAmountCents),
            decidedAt: str(dec.decidedAt),
            decidedByRole: str(dec.decidedByRole),
          }
        : null,
    payout:
      p && payId
        ? {
            id: payId,
            amountCents: num(p.amountCents),
            destinationLast4: str(p.destinationLast4),
            status: str(p.status),
            initiatedAt: str(p.initiatedAt),
          }
        : null,
  }
}

// ------------------------------------------------------------------ evidence

export function mapEvidenceList(raw: unknown): EvidenceItem[] {
  if (!isObj(raw) || !Array.isArray(raw.evidence)) return []
  const out: EvidenceItem[] = []
  for (const e of raw.evidence) {
    if (!isObj(e)) continue
    const id = str(e.id)
    if (!id) continue
    out.push({
      id,
      displayName: str(e.display_name),
      mimeType: str(e.mime_type),
      sizeBytes: num(e.size_bytes),
      sha256: str(e.sha256),
      createdAt: str(e.created_at),
    })
  }
  return out
}

export function mapEvidenceVerify(raw: unknown): EvidenceVerifyResult | null {
  if (!isObj(raw)) return null
  if (raw.status !== 'VALID' && raw.status !== 'TAMPERED') return null
  return {
    status: raw.status,
    expectedHash: str(raw.expectedHash),
    actualHash: str(raw.actualHash),
    reason: str(raw.reason),
  }
}

// ------------------------------------------------------------------ audit + platform views

export function mapAuditPage(raw: unknown): AuditPage {
  if (!isObj(raw)) return { events: [], nextBefore: null }
  const list = Array.isArray(raw.events) ? raw.events : []
  const events: AuditEvent[] = []
  for (const e of list) {
    if (!isObj(e)) continue
    const id = str(e.id)
    const action = str(e.action)
    if (!id || !action) continue
    events.push({
      id,
      occurredAt: str(e.occurredAt),
      actorId: str(e.actorId),
      actorRole: str(e.actorRole),
      action,
      resourceType: str(e.resourceType),
      resourceId: str(e.resourceId),
      outcome: str(e.outcome),
    })
  }
  return { events, nextBefore: str(raw.nextBefore) }
}

function mapScreeningMix(raw: unknown): ScreeningMix | null {
  if (!isObj(raw)) return null
  const NORMAL = num(raw.NORMAL)
  const ELEVATED = num(raw.ELEVATED)
  const HIGH = num(raw.HIGH)
  const unscreened = num(raw.unscreened)
  if (NORMAL === null || ELEVATED === null || HIGH === null || unscreened === null) return null
  return { NORMAL, ELEVATED, HIGH, unscreened }
}

/** GET /admin/integrity */
export function mapPlatformIntegrity(raw: unknown): PlatformIntegrity | null {
  if (!isObj(raw) || !isObj(raw.decisions) || !isObj(raw.screening)) return null
  const d = raw.decisions
  const total = num(d.total)
  const signed = num(d.signed)
  const unsigned = num(d.unsigned)
  const mix = mapScreeningMix(raw.screening)
  if (total === null || signed === null || unsigned === null || !mix) return null
  const byKeyId = Array.isArray(d.byKeyId)
    ? d.byKeyId.flatMap((k) => {
        if (!isObj(k)) return []
        const keyId = str(k.keyId)
        const count = num(k.count)
        return keyId && count !== null ? [{ keyId, count }] : []
      })
    : []
  const s = raw.screening
  const byModelVersion = Array.isArray(s.byModelVersion)
    ? s.byModelVersion.flatMap((m) => {
        if (!isObj(m)) return []
        const modelVersion = str(m.modelVersion)
        const count = num(m.count)
        return modelVersion && count !== null ? [{ modelVersion, count }] : []
      })
    : []
  return {
    generatedAt: str(raw.generatedAt),
    windowDays: num(raw.windowDays),
    decisions: { total, signed, unsigned, byKeyId },
    verificationsInWindow: numRecord(raw.verificationsInWindow),
    screening: { ...mix, byExecution: numRecord(s.byExecution), byModelVersion },
  }
}

/** The screening/integrity part of GET /tenant/overview. */
export function mapTenantOverview(raw: unknown): TenantOverviewSummary | null {
  if (!isObj(raw)) return null
  const t = isObj(raw.tenant) ? raw.tenant : null
  const tid = t ? str(t.id) : null
  const tname = t ? str(t.name) : null
  const i = isObj(raw.integrity) ? raw.integrity : null
  const signed = i ? num(i.signed) : null
  const unsigned = i ? num(i.unsigned) : null
  return {
    tenant: tid && tname ? { id: tid, name: tname } : null,
    generatedAt: str(raw.generatedAt),
    screening: mapScreeningMix(raw.screening),
    integrity:
      i && signed !== null && unsigned !== null
        ? { signed, unsigned, verificationsInWindow: numRecord(i.verificationsInWindow) }
        : null,
  }
}

/** GET /integrity/public-key */
export function mapPublicKey(raw: unknown): PublicKeyInfo | null {
  if (!isObj(raw)) return null
  const alg = str(raw.alg)
  const keyId = str(raw.keyId)
  if (!alg || !keyId) return null
  return {
    alg,
    keyId,
    standard: str(raw.standard),
    bundleVersion: str(raw.bundleVersion),
    context: str(raw.context),
    publicKey: str(raw.publicKey),
  }
}

// ------------------------------------------------------------------ display helpers

export const NONE = '—'

export function formatZAR(cents: number | null | undefined): string {
  if (cents === null || cents === undefined || !Number.isFinite(cents)) return NONE
  return (cents / 100).toLocaleString('en-ZA', { style: 'currency', currency: 'ZAR' })
}

export function formatDateTime(iso: string | null | undefined): string {
  if (!iso) return NONE
  const d = new Date(iso)
  return Number.isNaN(d.getTime()) ? NONE : d.toLocaleString()
}

export function formatDate(iso: string | null | undefined): string {
  if (!iso) return NONE
  const d = new Date(iso)
  return Number.isNaN(d.getTime()) ? NONE : d.toLocaleDateString()
}

/** Masked destination text, or null when the backend reported none (never a placeholder bank). */
export function destinationLabel(dest: { bankName: string | null; accountLast4: string | null } | null): string | null {
  if (!dest || !dest.accountLast4) return null
  return `${dest.bankName ?? 'Bank not stated'} (•••• ${dest.accountLast4})`
}

/** The Idempotency-Key the Flutter app uses for a payout; must match exactly. */
export function payIdempotencyKey(claimId: string): string {
  return `pay-${claimId}`
}
