import { createExecutionContext, waitOnExecutionContext } from 'cloudflare:test'
import { env } from 'cloudflare:workers'
import { sign } from 'hono/jwt'
import worker from '../src/index'
import type { Role } from '../src/types'

export const BASE = 'http://localhost/api/v1'

export interface TestActor {
  id: string
  role: Role | string
  tenantId?: string | null
}

export interface TokenOptions {
  /** Extra or overriding claims (e.g. { role: 'ADMIN' }, { exp: 1 }). */
  claims?: Record<string, unknown>
  /** Claims to delete after building the payload (e.g. ['exp']). */
  omit?: string[]
  /** Sign with a different secret (wrong-key tests). */
  secret?: string
  /** Sign with a different algorithm (alg-confusion tests). */
  alg?: 'HS256' | 'HS384' | 'HS512'
  /** Seconds until expiry (negative = already expired). */
  ttl?: number
}

/** Mints a real signed JWT the way the local auth service / mint script would. */
export async function mintToken(actor: TestActor, opts: TokenOptions = {}): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const payload: Record<string, unknown> = {
    sub: actor.id,
    role: actor.role,
    iss: env.JWT_ISSUER,
    aud: env.JWT_AUDIENCE,
    iat: now,
    exp: now + (opts.ttl ?? 300),
  }
  if (actor.tenantId) payload.tenant_id = actor.tenantId
  Object.assign(payload, opts.claims)
  for (const k of opts.omit ?? []) delete payload[k]
  return sign(payload, opts.secret ?? (env.JWT_SECRET as string), opts.alg ?? 'HS256')
}

export interface CallOptions {
  /** Authenticate as this actor (a token is minted). */
  as?: TestActor
  /** Send this exact Authorization header value instead (overrides `as`). */
  authorization?: string
  method?: string
  json?: unknown
  headers?: Record<string, string>
  env?: Partial<typeof env>
}

export async function call(path: string, opts: CallOptions = {}): Promise<Response> {
  const headers = new Headers(opts.headers)
  if (opts.authorization !== undefined) headers.set('Authorization', opts.authorization)
  else if (opts.as) headers.set('Authorization', `Bearer ${await mintToken(opts.as)}`)
  let body: string | undefined
  if (opts.json !== undefined) {
    headers.set('Content-Type', 'application/json')
    body = JSON.stringify(opts.json)
  }
  const request = new Request(`${BASE}${path}`, { method: opts.method ?? 'GET', headers, body })
  const ctx = createExecutionContext()
  // The real per-IP/per-actor limiter (100 req/60 s) is bypassed for functional tests, which
  // issue hundreds of requests as the same actor; hardening.test.ts injects its own limiter.
  const response = await worker.fetch(request, { ...env, RATE_LIMITER: undefined, ...opts.env }, ctx)
  await waitOnExecutionContext(ctx)
  return response
}

// Seed data: tenant A = ins_discovery (claim_disc_101, Review), tenant B = ins_sanlam
// (claim_sanlam_102, Decision/Approved), tenant C = ins_momentum (claim_mom_103, Submitted).
export const customerA = { id: 'user123', role: 'CUSTOMER' } as const // owns claim_disc_101, claim_sanlam_102
export const customerB = { id: 'user456', role: 'CUSTOMER' } as const // owns no claims
export const assessorA = { id: 'assessor_a1', role: 'ASSESSOR', tenantId: 'ins_discovery' } as const
export const managerA = { id: 'manager_a1', role: 'MANAGER', tenantId: 'ins_discovery' } as const
export const assessorB = { id: 'assessor_b1', role: 'ASSESSOR', tenantId: 'ins_sanlam' } as const
export const managerB = { id: 'manager_b1', role: 'MANAGER', tenantId: 'ins_sanlam' } as const
export const admin = { id: 'admin1', role: 'ADMIN' } as const
// Phase 0 aliases (tenant A staff).
export const assessor = assessorA
export const manager = managerA

export async function auditRows(action: string, resourceId?: string) {
  const sql = resourceId
    ? 'SELECT * FROM audit_events WHERE action = ? AND resource_id = ? ORDER BY occurred_at, rowid'
    : 'SELECT * FROM audit_events WHERE action = ? ORDER BY occurred_at, rowid'
  const stmt = env.DB.prepare(sql)
  const { results } = await (resourceId ? stmt.bind(action, resourceId) : stmt.bind(action)).all()
  return results as Record<string, unknown>[]
}

export async function claimStage(claimId: string) {
  return env.DB.prepare('SELECT stage, status, tenant_id FROM claims WHERE id = ?').bind(claimId).first<{
    stage: string
    status: string
    tenant_id: string | null
  }>()
}

/** The legitimate demo payout: R4 200 to a masked demo account. */
export const DEMO_PAYOUT = {
  claimedAmountCents: 420_000,
  bankName: 'Demo Bank',
  accountHolder: 'Customer A',
  accountNumber: '62001234567890',
} as const

export async function setPayoutDetails(
  claimId: string,
  overrides: Partial<{ claimedAmountCents: number; bankName: string; accountHolder: string; accountNumber: string }> = {}
) {
  return call(`/claims/${claimId}/payout-details`, { method: 'PUT', as: customerA, json: { ...DEMO_PAYOUT, ...overrides } })
}

/** Creates a Draft claim for user123 on a Discovery (tenant A) policy with completed screening and payout details. */
export async function createReadyDraft(): Promise<string> {
  const res = await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001' } })
  const { claimId } = (await res.json()) as { claimId: string }
  await call(`/claims/${claimId}/screening`, {
    method: 'PATCH',
    as: customerA,
    json: { causeOfLoss: 'Hospital admission', incidentDate: '2026-01-10' },
  })
  const details = await setPayoutDetails(claimId)
  if (details.status !== 200) throw new Error(`payout details failed: ${details.status} ${await details.text()}`)
  return claimId
}

/** Drives a tenant-A claim to Review (customer submits, assessor verifies/screens/reviews). */
export async function createReviewedClaim(): Promise<string> {
  const claimId = await createSubmittedClaim()
  for (const step of ['verify', 'screen', 'review']) {
    const res = await call(`/claims/${claimId}/${step}`, { method: 'POST', as: assessorA })
    if (res.status !== 200) throw new Error(`${step} failed: ${res.status}`)
  }
  return claimId
}

export async function decisionRows(claimId: string) {
  return (await env.DB.prepare('SELECT * FROM claim_decisions WHERE claim_id = ? ORDER BY decided_at').bind(claimId).all()).results as Record<string, unknown>[]
}

export async function payoutRows(claimId: string) {
  return (await env.DB.prepare('SELECT * FROM payouts WHERE claim_id = ?').bind(claimId).all()).results as Record<string, unknown>[]
}

/** Creates a tenant-A claim and submits it (stage Submitted). */
export async function createSubmittedClaim(): Promise<string> {
  const claimId = await createReadyDraft()
  const res = await call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA })
  if (res.status !== 200) throw new Error(`submit failed: ${res.status}`)
  return claimId
}
