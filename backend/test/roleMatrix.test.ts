import { env } from 'cloudflare:workers'
import { beforeAll, describe, expect, it } from 'vitest'
import {
  assessorA,
  assessorB,
  call,
  createReviewedClaim,
  customerA,
  customerB,
  insurerAdminA,
  managerA,
  mintToken,
  superadmin,
  type TestActor,
} from './helpers'

// Table-driven check of docs/admin/ROLE_MATRIX.md against the real routes.
// Seed: claim_disc_101 (ins_discovery, Review, owner user123), claim_sanlam_102 (ins_sanlam).
// ALLOWED means "the role gate let it through": any status except 401/403/404 (the handler may
// still answer 409 for a wrong stage, which is the state machine, not RBAC).

const ALLOWED = 'ALLOWED' as const
type Expect = number | typeof ALLOWED
type Row = { name: string; method?: string; path: string | (() => string); json?: unknown; as?: TestActor; expect: Expect }

let reviewedId = ''

beforeAll(async () => {
  reviewedId = await createReviewedClaim()
  // A second platform admin, to prove superadmins cannot be managed through the API.
  await env.DB.prepare(
    "INSERT INTO users (id, username, password_hash, role, tenant_id, display_name, status, created_at) VALUES ('usr_super2', 'superadmin2', 'x', 'SUPERADMIN', NULL, 'Second Platform Admin', 'active', '2026-09-26T00:00:00Z')"
  ).run()
})

const APPROVE = { outcome: 'Approved', reason: 'Documents verified, within cover' }
const staffAdmin = { username: 'new_admin_disc', password: 'password-123', displayName: 'New Admin', role: 'INSURER_ADMIN', tenantId: 'ins_discovery' }

const ROWS: Row[] = [
  // ---- reading a claim (tenant boundary: another tenant's claim is 404, never 403)
  { name: 'anonymous reads a claim', path: '/claims/claim_disc_101', expect: 401 },
  { name: 'owner customer reads own claim', path: '/claims/claim_disc_101', as: customerA, expect: 200 },
  { name: 'other customer reads it', path: '/claims/claim_disc_101', as: customerB, expect: 404 },
  { name: 'assessor A reads tenant A claim', path: '/claims/claim_disc_101', as: assessorA, expect: 200 },
  { name: 'manager A reads tenant A claim', path: '/claims/claim_disc_101', as: managerA, expect: 200 },
  { name: 'insurer admin A reads tenant A claim (read-only view)', path: '/claims/claim_disc_101', as: insurerAdminA, expect: 200 },
  { name: 'superadmin reads a claim (platform operator: never)', path: '/claims/claim_disc_101', as: superadmin, expect: 404 },
  { name: 'superadmin lists claims', path: '/claims', as: superadmin, expect: 403 },
  { name: 'superadmin reads evidence', path: '/claims/claim_disc_101/evidence', as: superadmin, expect: 404 },
  { name: 'superadmin verifies a decision signature', path: '/claims/claim_sanlam_102/decision/verify', as: superadmin, expect: 404 },
  { name: 'superadmin disables an assessor', method: 'PATCH', path: '/admin/users/assessor_b1', json: { status: 'disabled' }, as: superadmin, expect: 404 },
  { name: 'assessor B reads tenant A claim', path: '/claims/claim_disc_101', as: assessorB, expect: 404 },
  { name: 'assessor A reads tenant B claim', path: '/claims/claim_sanlam_102', as: assessorA, expect: 404 },
  { name: 'manager A reads tenant B claim', path: '/claims/claim_sanlam_102', as: managerA, expect: 404 },
  { name: 'insurer admin A reads tenant B claim', path: '/claims/claim_sanlam_102', as: insurerAdminA, expect: 404 },

  // ---- advisory screening signal: claim staff only
  { name: 'customer reads risk signals', path: '/claims/claim_disc_101/risk-signals', as: customerA, expect: 403 },
  { name: 'assessor reads risk signals', path: '/claims/claim_disc_101/risk-signals', as: assessorA, expect: ALLOWED },
  { name: 'insurer admin reads risk signals', path: '/claims/claim_disc_101/risk-signals', as: insurerAdminA, expect: 403 },
  { name: 'superadmin reads risk signals', path: '/claims/claim_disc_101/risk-signals', as: superadmin, expect: 403 },

  // ---- claim work: ASSESSOR/MANAGER prepare, MANAGER alone decides and pays
  { name: 'customer verifies', method: 'POST', path: '/claims/claim_disc_101/verify', as: customerA, expect: 403 },
  { name: 'assessor verifies (wrong stage → state machine)', method: 'POST', path: '/claims/claim_disc_101/verify', as: assessorA, expect: ALLOWED },
  { name: 'insurer admin verifies', method: 'POST', path: '/claims/claim_disc_101/verify', as: insurerAdminA, expect: 403 },
  { name: 'superadmin verifies', method: 'POST', path: '/claims/claim_disc_101/verify', as: superadmin, expect: 403 },
  { name: 'insurer admin requests info', method: 'POST', path: '/claims/claim_disc_101/request-info', as: insurerAdminA, expect: 403 },
  { name: 'customer decides', method: 'POST', path: () => `/claims/${reviewedId}/decide`, json: APPROVE, as: customerA, expect: 403 },
  { name: 'assessor decides', method: 'POST', path: () => `/claims/${reviewedId}/decide`, json: APPROVE, as: assessorA, expect: 403 },
  { name: 'insurer admin decides', method: 'POST', path: () => `/claims/${reviewedId}/decide`, json: APPROVE, as: insurerAdminA, expect: 403 },
  { name: 'superadmin decides', method: 'POST', path: () => `/claims/${reviewedId}/decide`, json: APPROVE, as: superadmin, expect: 403 },
  { name: 'insurer admin pays', method: 'POST', path: '/claims/claim_disc_101/pay', json: {}, as: insurerAdminA, expect: 403 },
  { name: 'superadmin pays', method: 'POST', path: '/claims/claim_disc_101/pay', json: {}, as: superadmin, expect: 403 },
  { name: 'manager decides (last: this one changes state)', method: 'POST', path: () => `/claims/${reviewedId}/decide`, json: APPROVE, as: managerA, expect: 200 },
  { name: 'assessor pays a decided claim', method: 'POST', path: () => `/claims/${reviewedId}/pay`, json: {}, as: assessorA, expect: 403 },

  // ---- customer-only actions
  { name: 'assessor starts a claim', method: 'POST', path: '/claims/initiate', json: { policyId: 'pol_disc_001' }, as: assessorA, expect: 403 },
  { name: 'insurer admin starts a claim', method: 'POST', path: '/claims/initiate', json: { policyId: 'pol_disc_001' }, as: insurerAdminA, expect: 403 },
  { name: 'superadmin starts a claim', method: 'POST', path: '/claims/initiate', json: { policyId: 'pol_disc_001' }, as: superadmin, expect: 403 },

  // ---- platform administration: SUPERADMIN only
  { name: 'customer lists platform accounts', path: '/admin/users', as: customerA, expect: 403 },
  { name: 'manager lists platform accounts', path: '/admin/users', as: managerA, expect: 403 },
  { name: 'insurer admin lists platform accounts', path: '/admin/users', as: insurerAdminA, expect: 403 },
  { name: 'superadmin lists platform accounts', path: '/admin/users', as: superadmin, expect: 200 },
  { name: 'insurer admin creates an insurer admin via /admin', method: 'POST', path: '/admin/users', json: staffAdmin, as: insurerAdminA, expect: 403 },
  { name: 'superadmin creates a SUPERADMIN via API', method: 'POST', path: '/admin/users', json: { ...staffAdmin, username: 'evil_super', role: 'SUPERADMIN', tenantId: undefined }, as: superadmin, expect: 400 },
  { name: 'superadmin creates an ASSESSOR via /admin', method: 'POST', path: '/admin/users', json: { ...staffAdmin, username: 'odd_assessor', role: 'ASSESSOR' }, as: superadmin, expect: 400 },
  { name: 'superadmin creates an insurer admin', method: 'POST', path: '/admin/users', json: staffAdmin, as: superadmin, expect: 201 },
  { name: 'superadmin disables another superadmin', method: 'PATCH', path: '/admin/users/usr_super2', json: { status: 'disabled' }, as: superadmin, expect: 409 },
  { name: 'superadmin creates an insurer', method: 'POST', path: '/admin/tenants', json: { id: 'ins_matrix_test', name: 'Matrix Insurer' }, as: superadmin, expect: 201 },
  { name: 'insurer admin creates an insurer', method: 'POST', path: '/admin/tenants', json: { id: 'ins_matrix_two', name: 'Nope' }, as: insurerAdminA, expect: 403 },

  // ---- tenant administration: INSURER_ADMIN, own tenant only
  { name: 'assessor lists tenant staff', path: '/tenant/users', as: assessorA, expect: 403 },
  { name: 'manager lists tenant staff', path: '/tenant/users', as: managerA, expect: 403 },
  { name: 'superadmin uses the tenant console', path: '/tenant/users', as: superadmin, expect: 403 },
  { name: 'insurer admin lists own staff', path: '/tenant/users', as: insurerAdminA, expect: 200 },
  { name: 'insurer admin creates an assessor', method: 'POST', path: '/tenant/users', json: { username: 'new_assessor_disc', password: 'password-123', displayName: 'New Assessor', role: 'ASSESSOR' }, as: insurerAdminA, expect: 201 },
  { name: 'insurer admin creates a SUPERADMIN', method: 'POST', path: '/tenant/users', json: { username: 'evil_super2', password: 'password-123', displayName: 'Evil', role: 'SUPERADMIN' }, as: insurerAdminA, expect: 400 },
  { name: 'insurer admin names another tenant', method: 'POST', path: '/tenant/users', json: { username: 'x_sanlam', password: 'password-123', displayName: 'X', role: 'ASSESSOR', tenantId: 'ins_sanlam' }, as: insurerAdminA, expect: 400 },
  { name: 'insurer admin disables another tenant’s staff', method: 'PATCH', path: '/tenant/users/assessor_b1', json: { status: 'disabled' }, as: insurerAdminA, expect: 404 },
  { name: 'insurer admin disables a superadmin', method: 'PATCH', path: '/tenant/users/usr_superadmin', json: { status: 'disabled' }, as: insurerAdminA, expect: 404 },

  // ---- dashboards
  { name: 'manager opens tenant dashboard', path: '/tenant/overview', as: managerA, expect: 403 },
  { name: 'insurer admin opens tenant dashboard', path: '/tenant/overview', as: insurerAdminA, expect: 200 },
  { name: 'insurer admin opens platform dashboard', path: '/admin/overview', as: insurerAdminA, expect: 403 },
  { name: 'superadmin opens platform dashboard', path: '/admin/overview', as: superadmin, expect: 200 },

  // ---- retired dev login (magic word granted a role) is gone
  { name: 'retired /profile/login without token', method: 'POST', path: '/profile/login', json: { username: 'manager', password: 'x' }, expect: 401 },
  { name: 'retired /profile/login with a customer token', method: 'POST', path: '/profile/login', json: { username: 'manager', password: 'x' }, as: customerA, expect: 404 },
]

describe('role / permission / tenant matrix (docs/admin/ROLE_MATRIX.md)', () => {
  for (const row of ROWS) {
    it(`${row.name} → ${row.expect}`, async () => {
      const path = typeof row.path === 'function' ? row.path() : row.path
      const res = await call(path, { method: row.method ?? 'GET', as: row.as, json: row.json })
      if (row.expect === ALLOWED) expect([401, 403, 404]).not.toContain(res.status)
      else expect(res.status).toBe(row.expect)
    })
  }
})

describe('forged or tampered admin tokens never reach an admin route', () => {
  const cases: [string, () => Promise<string>, string][] = [
    ['SUPERADMIN signed with the wrong secret', () => mintToken(superadmin, { secret: 'z'.repeat(64) }), '/admin/overview'],
    ['SUPERADMIN, expired', () => mintToken(superadmin, { ttl: -60 }), '/admin/overview'],
    ['SUPERADMIN, wrong issuer', () => mintToken(superadmin, { claims: { iss: 'someone-else' } }), '/admin/overview'],
    ['SUPERADMIN, wrong audience', () => mintToken(superadmin, { claims: { aud: 'other-api' } }), '/admin/overview'],
    ['SUPERADMIN, lifetime beyond the 8 h staff cap', () => mintToken(superadmin, { ttl: 9 * 3600 }), '/admin/overview'],
    ['SUPERADMIN, HS512 instead of the pinned HS256', () => mintToken(superadmin, { alg: 'HS512' }), '/admin/overview'],
    ['SUPERADMIN carrying a tenant', () => mintToken({ ...superadmin, tenantId: 'ins_discovery' }), '/admin/overview'],
    ['customer token re-labelled SUPERADMIN with the wrong secret', () => mintToken(customerA, { claims: { role: 'SUPERADMIN' }, secret: 'q'.repeat(64) }), '/admin/users'],
    ['INSURER_ADMIN signed with the wrong secret', () => mintToken(insurerAdminA, { secret: 'z'.repeat(64) }), '/tenant/overview'],
    ['INSURER_ADMIN without a tenant', () => mintToken({ id: 'usr_admin_discovery', role: 'INSURER_ADMIN' }), '/tenant/overview'],
    ['INSURER_ADMIN, missing exp', () => mintToken(insurerAdminA, { omit: ['exp'] }), '/tenant/audit'],
  ]
  for (const [name, token, path] of cases) {
    it(`${name} → 401`, async () => {
      const res = await call(path, { authorization: `Bearer ${await token()}` })
      expect(res.status).toBe(401)
      expect(await res.json()).toEqual({ error: 'unauthenticated' })
    })
  }

  it('an unsigned (alg none) SUPERADMIN token → 401', async () => {
    const b64u = (s: string) => btoa(s).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_')
    const now = Math.floor(Date.now() / 1000)
    const body = { sub: 'usr_superadmin', role: 'SUPERADMIN', iss: env.JWT_ISSUER, aud: env.JWT_AUDIENCE, iat: now, exp: now + 300 }
    const token = `${b64u('{"alg":"none","typ":"JWT"}')}.${b64u(JSON.stringify(body))}.`
    expect((await call('/admin/overview', { authorization: `Bearer ${token}` })).status).toBe(401)
  })

  it('a role header or body field never upgrades a token', async () => {
    expect((await call('/admin/overview', { as: customerA, headers: { 'X-Role': 'SUPERADMIN', 'X-Tenant-Id': 'ins_discovery' } })).status).toBe(403)
    expect((await call('/tenant/overview', { as: assessorA, headers: { 'X-Role': 'INSURER_ADMIN' } })).status).toBe(403)
  })
})
