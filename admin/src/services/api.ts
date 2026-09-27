import type {
  AuditPage,
  ClaimDetail,
  ClaimSummary,
  DecisionInfo,
  DecisionIntegrity,
  EvidenceItem,
  EvidenceVerifyResult,
  PayoutView,
  PlatformIntegrity,
  PublicKeyInfo,
  RiskSignals,
  Session,
  TenantOverviewSummary,
  Timeline,
} from '../types'
import {
  isObj,
  mapAuditPage,
  mapClaimDetail,
  mapClaimList,
  mapDecision,
  mapDecisionIntegrity,
  mapEvidenceList,
  mapEvidenceVerify,
  mapLoginResponse,
  mapPayout,
  mapPlatformIntegrity,
  mapPublicKey,
  mapRiskSignals,
  mapTenantOverview,
  mapTimeline,
  parseStoredSession,
  payIdempotencyKey,
  str,
} from './mappers'

/**
 * The team backend. Cloudflare Pages cannot proxy /api/* to another domain, so the app calls the
 * Worker directly (its ALLOWED_ORIGINS includes easy-claim-admin-frontend.pages.dev and local dev).
 * Override with VITE_API_BASE at build time.
 */
export const API_BASE: string = import.meta.env.VITE_API_BASE ?? 'https://easy-claim-backend.pasekamabitsela22.workers.dev'

// sessionStorage: the token does not outlive the browser tab. Only token + backend actor are stored.
const SESSION_KEY = 'easyclaim_admin_session'
// Removed on load: the old build stored a fabricated "user" (and dev_token_*) under this key.
const LEGACY_KEY = 'easyclaim_admin_auth'

/** An error from the backend, with its HTTP status and `error` code. */
export class ApiError extends Error {
  readonly status: number
  readonly code: string | null
  constructor(status: number, code: string | null, message?: string) {
    super(message ?? code ?? `Request failed (${status})`)
    this.status = status
    this.code = code
  }
}

export interface ActionResult {
  ok: boolean
  message: string
}

/** Convenience persona list: pre-fills a username only. Roles/tenants shown come from the backend. */
export const PERSONA_USERNAMES: { username: string; hint: string }[] = [
  { username: 'assessor_discovery', hint: 'Assessor (Discovery)' },
  { username: 'manager_discovery', hint: 'Manager (Discovery)' },
  { username: 'admin_discovery', hint: 'Insurer admin (Discovery)' },
  { username: 'assessor_sanlam', hint: 'Assessor (Sanlam)' },
  { username: 'manager_sanlam', hint: 'Manager (Sanlam)' },
  { username: 'admin_sanlam', hint: 'Insurer admin (Sanlam)' },
  { username: 'superadmin', hint: 'Platform superadmin' },
]

function readStoredSession(): Session | null {
  try {
    localStorage.removeItem(LEGACY_KEY)
  } catch {
    /* storage unavailable */
  }
  try {
    const raw = sessionStorage.getItem(SESSION_KEY)
    return raw ? parseStoredSession(JSON.parse(raw)) : null
  } catch {
    return null
  }
}

async function readJson(res: Response): Promise<unknown> {
  return res.json().catch(() => null)
}

function errorCode(body: unknown): string | null {
  return isObj(body) ? str(body.error) : null
}

export class ApiService {
  private static session: Session | null = readStoredSession()
  private static unauthorizedListeners = new Set<() => void>()

  static getSession(): Session | null {
    if (this.session && this.session.expiresAt !== null && this.session.expiresAt <= Date.now()) {
      this.setSession(null)
    }
    return this.session
  }

  private static setSession(session: Session | null) {
    this.session = session
    try {
      if (session) sessionStorage.setItem(SESSION_KEY, JSON.stringify(session))
      else sessionStorage.removeItem(SESSION_KEY)
    } catch {
      /* storage unavailable: session lives in memory only */
    }
  }

  /** Called whenever the backend answers 401 (the session is cleared first). */
  static onUnauthorized(listener: () => void): () => void {
    this.unauthorizedListeners.add(listener)
    return () => this.unauthorizedListeners.delete(listener)
  }

  /**
   * POST /auth/login. The session is replaced only on success; a failed attempt leaves any
   * current session (and therefore the displayed user and role) untouched.
   */
  static async login(username: string, password: string): Promise<Session> {
    let res: Response
    try {
      res = await fetch(`${API_BASE}/api/v1/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      })
    } catch {
      throw new ApiError(0, 'network_error', 'Could not reach the EasyClaim backend.')
    }
    const body = await readJson(res)
    if (!res.ok) {
      const code = errorCode(body)
      const message =
        code === 'invalid_credentials'
          ? 'Incorrect username or password.'
          : code === 'validation_failed'
            ? 'Enter a valid username and a password of at least 6 characters.'
            : `Sign-in failed (${code ?? res.status}).`
      throw new ApiError(res.status, code, message)
    }
    const session = mapLoginResponse(body)
    if (!session) throw new ApiError(res.status, 'bad_response', 'The sign-in response did not include a token and role.')
    this.setSession(session)
    return session
  }

  static logout() {
    this.setSession(null)
  }

  private static async request(path: string, init: RequestInit = {}): Promise<unknown> {
    const session = this.getSession()
    if (!session) {
      this.notifyUnauthorized()
      throw new ApiError(401, 'not_signed_in', 'Not signed in.')
    }
    const headers: Record<string, string> = {
      Authorization: `Bearer ${session.token}`,
      ...(init.body !== undefined ? { 'Content-Type': 'application/json' } : {}),
      ...((init.headers as Record<string, string> | undefined) ?? {}),
    }
    let res: Response
    try {
      res = await fetch(`${API_BASE}/api/v1${path}`, { ...init, headers })
    } catch {
      throw new ApiError(0, 'network_error', 'Could not reach the EasyClaim backend.')
    }
    const body = await readJson(res)
    if (res.status === 401) {
      // Only drop the session if it is still the one this request was made with.
      if (this.session === session) this.notifyUnauthorized()
      throw new ApiError(401, errorCode(body), 'Your session has expired. Please sign in again.')
    }
    if (!res.ok) throw new ApiError(res.status, errorCode(body))
    return body
  }

  private static notifyUnauthorized() {
    this.setSession(null)
    for (const l of this.unauthorizedListeners) l()
  }

  private static async action(path: string, init: RequestInit, success: (body: unknown) => string): Promise<ActionResult> {
    try {
      const body = await this.request(path, { method: 'POST', ...init })
      return { ok: true, message: success(body) }
    } catch (err) {
      return { ok: false, message: describeError(err) }
    }
  }

  // ---------------------------------------------------------------- reads

  static async fetchClaims(): Promise<ClaimSummary[]> {
    return mapClaimList(await this.request('/claims?limit=50'))
  }

  static async fetchClaimDetail(claimId: string): Promise<ClaimDetail | null> {
    return mapClaimDetail(await this.request(`/claims/${encodeURIComponent(claimId)}`))
  }

  static async fetchTimeline(claimId: string): Promise<Timeline> {
    return mapTimeline(await this.request(`/claims/${encodeURIComponent(claimId)}/timeline`))
  }

  /** ASSESSOR/MANAGER only. null = no signal has been computed for this claim. */
  static async fetchRiskSignals(claimId: string): Promise<RiskSignals | null> {
    return mapRiskSignals(await this.request(`/claims/${encodeURIComponent(claimId)}/risk-signals`))
  }

  static async fetchDecision(claimId: string): Promise<DecisionInfo | null> {
    return mapDecision(await this.request(`/claims/${encodeURIComponent(claimId)}/decision`))
  }

  /** Re-verifies the stored decision's ML-DSA signature on the server. Audited by the backend. */
  static async verifyDecisionIntegrity(claimId: string): Promise<DecisionIntegrity | null> {
    return mapDecisionIntegrity(await this.request(`/claims/${encodeURIComponent(claimId)}/decision/verify`))
  }

  static async fetchPayout(claimId: string): Promise<PayoutView | null> {
    return mapPayout(await this.request(`/claims/${encodeURIComponent(claimId)}/payout`))
  }

  static async fetchEvidence(claimId: string): Promise<EvidenceItem[]> {
    return mapEvidenceList(await this.request(`/claims/${encodeURIComponent(claimId)}/evidence`))
  }

  /** Recomputes SHA-256 over the stored bytes on the server and compares with the upload hash. */
  static async verifyEvidence(claimId: string, evidenceId: string): Promise<EvidenceVerifyResult | null> {
    return mapEvidenceVerify(
      await this.request(`/claims/${encodeURIComponent(claimId)}/evidence/${encodeURIComponent(evidenceId)}/verify`)
    )
  }

  /** INSURER_ADMIN → /tenant/audit, SUPERADMIN → /admin/audit. Other roles have no audit view. */
  static async fetchAuditEvents(before?: string | null): Promise<AuditPage> {
    const role = this.getSession()?.actor.role
    const base = role === 'INSURER_ADMIN' ? '/tenant/audit' : role === 'SUPERADMIN' ? '/admin/audit' : null
    if (!base) throw new ApiError(403, 'forbidden', 'The audit log is available to insurer admins and the platform superadmin.')
    const q = new URLSearchParams({ limit: '50' })
    if (before) q.set('before', before)
    return mapAuditPage(await this.request(`${base}?${q.toString()}`))
  }

  static async fetchPlatformIntegrity(): Promise<PlatformIntegrity | null> {
    return mapPlatformIntegrity(await this.request('/admin/integrity'))
  }

  static async fetchTenantOverview(): Promise<TenantOverviewSummary | null> {
    return mapTenantOverview(await this.request('/tenant/overview'))
  }

  static async fetchPublicKey(): Promise<PublicKeyInfo | null> {
    return mapPublicKey(await this.request('/integrity/public-key'))
  }

  // ---------------------------------------------------------------- actions (ASSESSOR / MANAGER)

  static executeTransition(claimId: string, action: 'verify' | 'screen' | 'review'): Promise<ActionResult> {
    return this.action(`/claims/${encodeURIComponent(claimId)}/${action}`, {}, transitionMessage)
  }

  static requestInfo(claimId: string, message: string): Promise<ActionResult> {
    return this.action(
      `/claims/${encodeURIComponent(claimId)}/request-info`,
      { body: JSON.stringify({ message }) },
      transitionMessage
    )
  }

  static decideClaim(
    claimId: string,
    outcome: 'Approved' | 'Rejected',
    reason: string,
    approvedAmountCents?: number
  ): Promise<ActionResult> {
    const payload: Record<string, unknown> = { outcome, reason }
    if (outcome === 'Approved' && approvedAmountCents !== undefined) payload.approvedAmountCents = approvedAmountCents
    return this.action(`/claims/${encodeURIComponent(claimId)}/decide`, { body: JSON.stringify(payload) }, (body) => {
      const b = isObj(body) ? body : {}
      const integ = isObj(b.integrity) ? b.integrity : null
      const signed = integ && str(integ.alg) ? ` Signed with ${str(integ.alg)} (key ${str(integ.keyId) ?? '—'}).` : ''
      return `Decision recorded: ${str(b.outcome) ?? outcome}.${signed}`
    })
  }

  /** Simulated payout. Idempotency-Key is `pay-<claimId>`, the same key the Flutter app sends. */
  static payClaim(claimId: string): Promise<ActionResult> {
    return this.action(
      `/claims/${encodeURIComponent(claimId)}/pay`,
      { headers: { 'Idempotency-Key': payIdempotencyKey(claimId) } },
      (body) => {
        const b = isObj(body) ? body : {}
        const id = str(b.payoutId) ?? '—'
        return b.status === 'already_paid'
          ? `Already paid (payout ${id}); no second payout was made.`
          : `Simulated payout recorded (payout ${id}). No money moves.`
      }
    )
  }
}

function transitionMessage(body: unknown): string {
  const b = isObj(body) ? body : {}
  const from = str(b.from)
  const to = str(b.to)
  return from && to ? `Claim moved from ${from} to ${to}.` : 'Done.'
}

const ERROR_TEXT: Record<string, string> = {
  forbidden: 'Your role is not allowed to do this.',
  role_not_permitted: 'Your role is not allowed to perform this step.',
  illegal_transition: 'This step is not possible from the claim’s current stage.',
  not_found: 'Claim not found (or not in your tenant).',
  payout_details_missing: 'The customer has not provided a claimed amount and payout destination.',
  amount_exceeds_claimed: 'The approved amount cannot exceed the claimed amount.',
  integrity_unavailable: 'Decision signing is not configured on the server; nothing was recorded.',
  decision_integrity_failed: 'The decision’s signature did not verify. Payout refused.',
  destination_mismatch: 'The payout destination no longer matches the decision snapshot. Payout refused.',
  already_paid: 'This claim has already been paid.',
  not_approved: 'The claim is not approved.',
  validation_failed: 'The request was rejected as invalid.',
  // POPIA consent forms (migration 0015): the customer must sign before work continues.
  consent_required: 'Waiting for the customer to sign the POPIA consent form sent after verification.',
  consent_withdrawn: 'The customer withdrew consent. Send a new consent form from the EasyClaim app to continue.',
}

export function describeError(err: unknown): string {
  if (err instanceof ApiError) {
    if (err.code && ERROR_TEXT[err.code]) return ERROR_TEXT[err.code]
    return err.message
  }
  return err instanceof Error ? err.message : 'Unexpected error'
}
