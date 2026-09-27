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
  /** Extra or overriding claims (e.g. { role: 'SUPERADMIN' }, { exp: 1 }). */
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
  // Like the real login: carry the account's current session version (requireActor checks it).
  const row = await env.DB.prepare('SELECT token_version FROM users WHERE id = ?').bind(actor.id).first<{ token_version: number }>().catch(() => null)
  if (row) payload.ver = row.token_version
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
  /** Multipart body (e.g. a file upload); Content-Type/boundary is set by the runtime. */
  formData?: FormData
  headers?: Record<string, string>
  env?: Partial<typeof env>
}

export async function call(path: string, opts: CallOptions = {}): Promise<Response> {
  const headers = new Headers(opts.headers)
  if (opts.authorization !== undefined) headers.set('Authorization', opts.authorization)
  else if (opts.as) headers.set('Authorization', `Bearer ${await mintToken(opts.as)}`)
  let body: string | FormData | undefined
  if (opts.json !== undefined) {
    headers.set('Content-Type', 'application/json')
    body = JSON.stringify(opts.json)
  } else if (opts.formData) {
    body = opts.formData
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
// Final role model (26 Sep 2026): CUSTOMER, ASSESSOR, MANAGER, INSURER_ADMIN, SUPERADMIN.
// Ids match src/security/demoUsers.ts (seeded by test/setup.ts).
export const customerA = { id: 'user123', role: 'CUSTOMER' } as const // username mike; owns claim_disc_101, claim_sanlam_102
export const customerB = { id: 'user456', role: 'CUSTOMER' } as const // username lerato; owns no claims
export const assessorA = { id: 'assessor_a1', role: 'ASSESSOR', tenantId: 'ins_discovery' } as const // assessor_discovery
export const managerA = { id: 'manager_a1', role: 'MANAGER', tenantId: 'ins_discovery' } as const // manager_discovery
export const assessorB = { id: 'assessor_b1', role: 'ASSESSOR', tenantId: 'ins_sanlam' } as const // assessor_sanlam
export const managerB = { id: 'manager_b1', role: 'MANAGER', tenantId: 'ins_sanlam' } as const // manager_sanlam
export const insurerAdminA = { id: 'usr_admin_discovery', role: 'INSURER_ADMIN', tenantId: 'ins_discovery' } as const // admin_discovery
export const insurerAdminB = { id: 'usr_admin_sanlam', role: 'INSURER_ADMIN', tenantId: 'ins_sanlam' } as const // admin_sanlam
export const superadmin = { id: 'usr_superadmin', role: 'SUPERADMIN' } as const


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

// Minimal valid bytes for each allowed evidence type: real magic-byte headers plus filler so
// tampering tests have something to flip further into the file.
export const VALID_PDF_BYTES = new Uint8Array([...[0x25, 0x50, 0x44, 0x46, 0x2d], ...Array(32).fill(0x20)])
export const VALID_PNG_BYTES = new Uint8Array([...[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a], ...Array(32).fill(0)])

export function evidenceFile(bytes: Uint8Array = VALID_PDF_BYTES, name = 'receipt.pdf', type = 'application/pdf'): File {
  return new File([bytes], name, { type })
}

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

export async function evidenceRow(evidenceId: string) {
  return env.DB.prepare('SELECT * FROM evidence WHERE id = ?').bind(evidenceId).first<EvidenceRow>()
}

/** A valid South African ID number for a date of birth (YYMMDD), with a correct Luhn check digit. */
export function saIdNumber(yymmdd: string, serial = '5009', citizen = '08'): string {
  const body = `${yymmdd}${serial}${citizen}`
  for (let check = 0; check <= 9; check++) {
    const id = body + check
    let sum = 0
    for (let i = 0; i < 13; i++) {
      let d = Number(id[12 - i])
      if (i % 2 === 1) {
        d *= 2
        if (d > 9) d -= 9
      }
      sum += d
    }
    if (sum % 10 === 0) return id
  }
  throw new Error('unreachable')
}

/** Saves a customer profile (required before a policy-link request). */
export async function saveProfile(as: TestActor, overrides: Record<string, string> = {}) {
  return call('/covers/profile', {
    method: 'PUT',
    as,
    json: { legalName: 'Test Customer', email: 'test@example.com', phone: '+27 82 555 0101', dateOfBirth: '1990-05-14', idNumber: saIdNumber('900514'), ...overrides },
  })
}

/** Uploads a PDF for every required document of a request, then the tenant admin ticks each as checked. */
export async function completeDocuments(requestId: string, customer: TestActor, admin: TestActor) {
  const reqs = (await (await call(`/tenant/policy-requests/${requestId}`, { as: admin })).json()) as { request: { documents: { key: string; required: boolean }[] } }
  for (const d of reqs.request.documents.filter((x) => x.required)) {
    const fd = new FormData()
    fd.append('file', evidenceFile(VALID_PDF_BYTES, `${d.key}.pdf`))
    const up = await call(`/covers/link-requests/${requestId}/documents/${d.key}`, { method: 'POST', as: customer, formData: fd })
    if (up.status !== 201) throw new Error(`upload ${d.key}: ${up.status} ${await up.text()}`)
    const v = await call(`/tenant/policy-requests/${requestId}/documents/${d.key}/verify`, { method: 'POST', as: admin, json: { verified: true } })
    if (v.status !== 200) throw new Error(`verify ${d.key}: ${v.status}`)
  }
}
