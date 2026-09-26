import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
// Vite serves the seed script as text; TypeScript cannot type a relative `?raw` import.
// @ts-expect-error raw-text import resolved by Vite
import seedScript from '../scripts/seed-demo-users.mjs?raw'
import { DEMO_USERS } from '../src/security/demoUsers'
import { auditRows, call, customerA, insurerA, insurerB, superadmin } from './helpers'

// Accounts (team role model, 26 Sep 2026): POST /auth/login, POST /auth/register, GET /auth/me,
// SUPERADMIN /admin/*, INSURER_ADMIN /tenant/*. Demo users are seeded by test/setup.ts with the
// per-run DEMO_LOGIN_PASSWORD.

const PASSWORD = env.DEMO_LOGIN_PASSWORD as string
const json = async (res: Response) => (await res.json()) as Record<string, any>

async function login(body: unknown) {
  const res = await call('/auth/login', { method: 'POST', json: body })
  return { status: res.status, body: await json(res) }
}
async function bearer(username: string, password = PASSWORD): Promise<string> {
  const r = await login({ username, password })
  if (r.status !== 200) throw new Error(`login ${username} failed: ${r.status} ${JSON.stringify(r.body)}`)
  return `Bearer ${r.body.token}`
}
const strong = 'correct-horse-battery'

describe('ACCOUNTS: login', () => {
  it.each([
    ['mike', 'user123', 'CUSTOMER', null, 'Mike'],
    ['admin_discovery', 'usr_admin_discovery', 'INSURER_ADMIN', 'ins_discovery', 'Discovery Claims Admin'],
    ['superadmin', 'usr_superadmin', 'SUPERADMIN', null, 'EasyClaim Platform Admin'],
  ])('%s signs in and the token works on /auth/me and a role-appropriate route', async (username, id, role, tenantId, displayName) => {
    const r = await login({ username, password: PASSWORD })
    expect(r.status).toBe(200)
    expect(r.body).toMatchObject({ tokenType: 'Bearer', expiresIn: 3600, actor: { id, username, role, tenantId, displayName, status: 'active' } })
    expect(r.body.actor.password_hash).toBeUndefined()
    const auth = `Bearer ${r.body.token}`
    const me = await json(await call('/auth/me', { authorization: auth }))
    expect(me.actor).toEqual({ id, role, tenantId, username, displayName, status: 'active' })
    const route = role === 'CUSTOMER' ? '/covers/my-covers' : role === 'INSURER_ADMIN' ? '/tenant' : '/admin/tenants'
    expect((await call(route, { authorization: auth })).status).toBe(200)
    const ok = (await auditRows('auth.login', id)).find((row) => row.outcome === 'success')
    expect(JSON.parse(ok!.details as string)).toEqual({ role, tenantId })
  })

  it('wrong password and unknown username answer the same 401 body', async () => {
    const wrong = await login({ username: 'mike', password: 'not-the-password' })
    const unknown = await login({ username: 'nobody_here', password: PASSWORD })
    expect(wrong.status).toBe(401)
    expect(unknown.status).toBe(401)
    expect(wrong.body).toEqual({ error: 'invalid_credentials' })
    expect(unknown.body).toEqual(wrong.body)
    expect(wrong.body.token).toBeUndefined()
  })

  it('username is case-insensitive', async () => {
    expect((await login({ username: 'MIKE', password: PASSWORD })).status).toBe(200)
    expect((await login({ username: 'Admin_Discovery', password: PASSWORD })).body.actor.id).toBe('usr_admin_discovery')
  })

  it('a disabled account cannot sign in (401, audited account_disabled)', async () => {
    const admin = await bearer('superadmin')
    expect((await call('/admin/users/usr_admin_sanlam', { method: 'PATCH', authorization: admin, json: { status: 'disabled' } })).status).toBe(200)
    const r = await login({ username: 'admin_sanlam', password: PASSWORD })
    expect(r.status).toBe(401)
    expect(r.body).toEqual({ error: 'invalid_credentials' })
    const denied = (await auditRows('auth.login', 'usr_admin_sanlam')).filter((row) => row.outcome === 'denied')
    expect(JSON.parse(denied[denied.length - 1].details as string)).toEqual({ reason: 'account_disabled' })
    expect((await call('/admin/users/usr_admin_sanlam', { method: 'PATCH', authorization: admin, json: { status: 'active' } })).status).toBe(200)
    expect((await login({ username: 'admin_sanlam', password: PASSWORD })).status).toBe(200)
  })

  it.each([
    ['role', { username: 'mike', password: 'x', role: 'SUPERADMIN' }],
    ['tenantId', { username: 'mike', password: 'x', tenantId: 'ins_discovery' }],
    ['sub', { username: 'mike', password: 'x', sub: 'usr_superadmin' }],
    ['missing password', { username: 'mike' }],
    ['bad username chars', { username: 'mike; drop', password: 'x' }],
  ])('strict login body: %s → 400', async (_n, body) => {
    const r = await login(body)
    expect(r.status).toBe(400)
    expect(r.body.token).toBeUndefined()
  })

  it('audit rows for login never contain the password', async () => {
    await login({ username: 'mike', password: PASSWORD })
    await login({ username: 'mike', password: 'wrong-password-value' })
    const dump = JSON.stringify(await auditRows('auth.login'))
    expect(dump).not.toContain(PASSWORD)
    expect(dump).not.toContain('wrong-password-value')
  })

  it('unauthenticated /auth/me → 401; offline-minted tokens have no profile fields', async () => {
    expect((await call('/auth/me')).status).toBe(401)
    const me = await json(await call('/auth/me', { as: { id: 'ghost_1', role: 'CUSTOMER' } }))
    expect(me.actor).toEqual({ id: 'ghost_1', role: 'CUSTOMER', tenantId: null, username: null, displayName: null, status: null })
  })
})

describe('ACCOUNTS: customer self-registration', () => {
  it('creates a CUSTOMER, returns 201 with a working token, and can never set a role', async () => {
    const res = await call('/auth/register', { method: 'POST', json: { username: 'Thandi_01', password: strong, displayName: 'Thandi M' } })
    expect(res.status).toBe(201)
    const body = await json(res)
    expect(body.actor).toMatchObject({ username: 'thandi_01', role: 'CUSTOMER', tenantId: null, displayName: 'Thandi M', status: 'active' })
    expect(body.actor.id).toMatch(/^usr_[0-9a-f-]{36}$/)
    expect(body.actor.password_hash).toBeUndefined()
    const auth = `Bearer ${body.token}`
    const claims = await json(await call('/claims', { authorization: auth }))
    expect(claims.claims).toEqual([])
    expect((await call('/covers/my-covers', { authorization: auth })).status).toBe(200)
    expect((await call('/admin/tenants', { authorization: auth })).status).toBe(403)
    expect((await call('/tenant', { authorization: auth })).status).toBe(403)
    // the new account can sign in again (case-insensitively) and is audited without the password
    expect((await login({ username: 'THANDI_01', password: strong })).status).toBe(200)
    expect(JSON.stringify(await auditRows('auth.register'))).not.toContain(strong)
    expect((await auditRows('auth.register', body.actor.id))[0]).toMatchObject({ outcome: 'success' })
  })

  it('duplicate username → 409 username_taken (also against a seeded account)', async () => {
    const r = await call('/auth/register', { method: 'POST', json: { username: 'mike', password: strong, displayName: 'Another Mike' } })
    expect(r.status).toBe(409)
    expect(await json(r)).toEqual({ error: 'username_taken' })
  })

  it.each([
    ['role in body', { username: 'evil_1', password: strong, displayName: 'Evil', role: 'SUPERADMIN' }],
    ['tenantId in body', { username: 'evil_2', password: strong, displayName: 'Evil', tenantId: 'ins_discovery' }],
    ['password shorter than 6', { username: 'short_1', password: '12345', displayName: 'Short' }],
    ['missing displayName', { username: 'nodisp_1', password: strong }],
    ['username too short', { username: 'ab', password: strong, displayName: 'AB' }],
  ])('strict register body: %s → 400', async (_n, body) => {
    const r = await call('/auth/register', { method: 'POST', json: body })
    expect(r.status).toBe(400)
    expect((await json(r)).token).toBeUndefined()
  })

  it('a 6-character password is accepted (hackathon minimum)', async () => {
    expect((await call('/auth/register', { method: 'POST', json: { username: 'six_ok', password: '123456', displayName: 'Six' } })).status).toBe(201)
  })
})

describe('ACCOUNTS: /admin/* (SUPERADMIN)', () => {
  it('customer and insurer admin → 403 on every admin route', async () => {
    for (const who of [customerA, insurerA]) {
      expect((await call('/admin/tenants', { as: who })).status).toBe(403)
      expect((await call('/admin/tenants', { method: 'POST', as: who, json: { id: 'ins_x1', name: 'X' } })).status).toBe(403)
      expect((await call('/admin/users', { as: who })).status).toBe(403)
      expect((await call('/admin/users', { method: 'POST', as: who, json: { username: 'x_1', password: strong, displayName: 'X', role: 'SUPERADMIN' } })).status).toBe(403)
      expect((await call('/admin/stats', { as: who })).status).toBe(403)
    }
  })

  it('lists and creates tenants (duplicate 409, bad id 400)', async () => {
    const list = await json(await call('/admin/tenants', { as: superadmin }))
    expect(list.tenants).toContainEqual(expect.objectContaining({ id: 'ins_discovery', name: 'Discovery Health', admin_count: 1, policy_count: 1 }))
    const created = await call('/admin/tenants', { method: 'POST', as: superadmin, json: { id: 'ins_hollard', name: 'Hollard' } })
    expect(created.status).toBe(201)
    expect(await json(created)).toEqual({ tenant: { id: 'ins_hollard', name: 'Hollard' } })
    expect((await call('/admin/tenants', { method: 'POST', as: superadmin, json: { id: 'ins_hollard', name: 'Again' } })).status).toBe(409)
    expect((await call('/admin/tenants', { method: 'POST', as: superadmin, json: { id: 'hollard', name: 'No prefix' } })).status).toBe(400)
    expect((await call('/admin/tenants', { method: 'POST', as: superadmin, json: { id: 'ins_h2', name: 'H2', extra: 1 } })).status).toBe(400)
    expect((await auditRows('admin.tenant_created', 'ins_hollard'))[0]).toMatchObject({ actor_id: 'usr_superadmin', outcome: 'success' })
  })

  it('creates an INSURER_ADMIN (tenant required, must exist) and a SUPERADMIN (no tenant allowed)', async () => {
    const noTenant = await call('/admin/users', { method: 'POST', as: superadmin, json: { username: 'adm_new', password: strong, displayName: 'New', role: 'INSURER_ADMIN' } })
    expect(noTenant.status).toBe(422)
    expect(await json(noTenant)).toEqual({ error: 'tenant_required' })
    const unknown = await call('/admin/users', { method: 'POST', as: superadmin, json: { username: 'adm_new', password: strong, displayName: 'New', role: 'INSURER_ADMIN', tenantId: 'ins_nope' } })
    expect(await json(unknown)).toEqual({ error: 'unknown_tenant' })
    const ok = await call('/admin/users', { method: 'POST', as: superadmin, json: { username: 'adm_new', password: strong, displayName: 'New Admin', role: 'INSURER_ADMIN', tenantId: 'ins_momentum' } })
    expect(ok.status).toBe(201)
    const user = (await json(ok)).user
    expect(user).toMatchObject({ username: 'adm_new', role: 'INSURER_ADMIN', tenantId: 'ins_momentum', status: 'active' })
    expect(user.password_hash).toBeUndefined()
    // the new admin signs in and sees only Momentum
    const auth = await bearer('adm_new', strong)
    expect((await json(await call('/tenant', { authorization: auth }))).tenant).toEqual({ id: 'ins_momentum', name: 'Momentum' })
    const queue = await json(await call('/claims', { authorization: auth }))
    expect(queue.claims.map((c: { id: string }) => c.id)).toEqual(['claim_mom_103'])

    const superWithTenant = await call('/admin/users', { method: 'POST', as: superadmin, json: { username: 'root_2', password: strong, displayName: 'Root', role: 'SUPERADMIN', tenantId: 'ins_discovery' } })
    expect(await json(superWithTenant)).toEqual({ error: 'tenant_not_allowed' })
    const root = await call('/admin/users', { method: 'POST', as: superadmin, json: { username: 'root_2', password: strong, displayName: 'Root Two', role: 'SUPERADMIN' } })
    expect(root.status).toBe(201)
    expect((await call('/admin/stats', { authorization: await bearer('root_2', strong) })).status).toBe(200)
    // customers cannot be created here, and duplicates are refused
    expect((await call('/admin/users', { method: 'POST', as: superadmin, json: { username: 'cust_x', password: strong, displayName: 'C', role: 'CUSTOMER' } })).status).toBe(400)
    expect((await call('/admin/users', { method: 'POST', as: superadmin, json: { username: 'MIKE', password: strong, displayName: 'Dup', role: 'SUPERADMIN' } })).status).toBe(409)
    expect((await auditRows('admin.user_created', user.id))[0]).toMatchObject({ actor_id: 'usr_superadmin', outcome: 'success' })
  })

  it('lists accounts with and without a tenant filter; never returns password hashes or customers by default', async () => {
    const all = await json(await call('/admin/users', { as: superadmin }))
    const names = all.users.map((u: { username: string }) => u.username)
    expect(names).toEqual(expect.arrayContaining(['superadmin', 'admin_discovery', 'admin_sanlam']))
    expect(names).not.toContain('mike')
    expect(JSON.stringify(all)).not.toContain('pbkdf2')
    const disc = await json(await call('/admin/users?tenantId=ins_discovery', { as: superadmin }))
    expect(disc.users.map((u: { username: string }) => u.username)).toEqual(['admin_discovery'])
    expect((await call('/admin/users?tenantId=bad%20id', { as: superadmin })).status).toBe(400)
  })

  it('disables and re-enables an account; cannot change own status (409); unknown user 404', async () => {
    const off = await call('/admin/users/usr_admin_discovery', { method: 'PATCH', as: superadmin, json: { status: 'disabled' } })
    expect(off.status).toBe(200)
    expect((await json(off)).user).toMatchObject({ id: 'usr_admin_discovery', status: 'disabled' })
    expect((await login({ username: 'admin_discovery', password: PASSWORD })).status).toBe(401)
    const on = await call('/admin/users/usr_admin_discovery', { method: 'PATCH', as: superadmin, json: { status: 'active' } })
    expect((await json(on)).user.status).toBe('active')
    expect((await login({ username: 'admin_discovery', password: PASSWORD })).status).toBe(200)
    const self = await call('/admin/users/usr_superadmin', { method: 'PATCH', as: superadmin, json: { status: 'disabled' } })
    expect(self.status).toBe(409)
    expect(await json(self)).toEqual({ error: 'cannot_change_own_status' })
    expect((await call('/admin/users/usr_nobody', { method: 'PATCH', as: superadmin, json: { status: 'disabled' } })).status).toBe(404)
    expect((await call('/admin/users/usr_admin_discovery', { method: 'PATCH', as: superadmin, json: { status: 'deleted' } })).status).toBe(400)
    expect((await auditRows('admin.user_status_changed', 'usr_admin_discovery')).length).toBe(2)
  })

  it('stats: tenants, usersByRole, claims.byStage, perTenant', async () => {
    const stats = await json(await call('/admin/stats', { as: superadmin }))
    const tenantCount = (await env.DB.prepare('SELECT count(*) AS n FROM tenants').first<{ n: number }>())!.n
    expect(stats.tenants).toBe(tenantCount)
    expect(stats.tenants).toBeGreaterThanOrEqual(5)
    for (const role of ['CUSTOMER', 'INSURER_ADMIN', 'SUPERADMIN']) {
      const n = (await env.DB.prepare('SELECT count(*) AS n FROM users WHERE role = ?').bind(role).first<{ n: number }>())!.n
      expect(stats.usersByRole[role], role).toBe(n)
    }
    expect(stats.usersByRole).toMatchObject({ SUPERADMIN: expect.any(Number), INSURER_ADMIN: expect.any(Number), CUSTOMER: expect.any(Number) })
    expect(stats.claims).toMatchObject({ total: 3, byStage: { Review: 1, Decision: 1, Submitted: 1 } })
    expect(stats.perTenant).toContainEqual({ tenantId: 'ins_discovery', name: 'Discovery Health', claims: { total: 1, byStage: { Review: 1 } } })
    expect(stats.perTenant).toHaveLength(tenantCount)
    expect(JSON.stringify(stats)).not.toContain('pbkdf2')
  })
})

describe('ACCOUNTS: /tenant/* (INSURER_ADMIN, own tenant only)', () => {
  it('superadmin and customer → 403', async () => {
    for (const who of [superadmin, customerA]) {
      expect((await call('/tenant', { as: who })).status).toBe(403)
      expect((await call('/tenant/users', { as: who })).status).toBe(403)
      expect((await call('/tenant/users', { method: 'POST', as: who, json: { username: 'x_2', password: strong, displayName: 'X' } })).status).toBe(403)
      expect((await call('/tenant/stats', { as: who })).status).toBe(403)
    }
  })

  it('sees its own tenant, users and stats', async () => {
    expect((await json(await call('/tenant', { as: insurerA }))).tenant).toEqual({ id: 'ins_discovery', name: 'Discovery Health' })
    const users = await json(await call('/tenant/users', { as: insurerA }))
    expect(users.users.map((u: { username: string }) => u.username)).toEqual(['admin_discovery'])
    expect(JSON.stringify(users)).not.toContain('pbkdf2')
    expect(await json(await call('/tenant/stats', { as: insurerA }))).toEqual({ tenantId: 'ins_discovery', claims: { total: 1, byStage: { Review: 1 } } })
  })

  it('creates an admin for its own tenant only (a tenantId or role in the body → 400) and the new admin works', async () => {
    expect((await call('/tenant/users', { method: 'POST', as: insurerA, json: { username: 'disc_2', password: strong, displayName: 'D2', tenantId: 'ins_sanlam' } })).status).toBe(400)
    expect((await call('/tenant/users', { method: 'POST', as: insurerA, json: { username: 'disc_2', password: strong, displayName: 'D2', role: 'SUPERADMIN' } })).status).toBe(400)
    const res = await call('/tenant/users', { method: 'POST', as: insurerA, json: { username: 'disc_2', password: strong, displayName: 'Discovery Admin 2' } })
    expect(res.status).toBe(201)
    const user = (await json(res)).user
    expect(user).toMatchObject({ role: 'INSURER_ADMIN', tenantId: 'ins_discovery', status: 'active' })
    expect((await auditRows('tenant.user_created', user.id))[0]).toMatchObject({ actor_id: 'usr_admin_discovery', actor_tenant_id: 'ins_discovery' })
    const auth = await bearer('disc_2', strong)
    expect((await call('/claims/claim_disc_101/review', { method: 'POST', as: undefined, authorization: auth })).status).not.toBe(403)
    expect((await call('/claims/claim_sanlam_102', { authorization: auth })).status).toBe(404)
    expect((await call('/tenant/users', { method: 'POST', as: insurerA, json: { username: 'DISC_2', password: strong, displayName: 'Dup' } })).status).toBe(409)
  })

  it('disables an admin of its own tenant; cross-tenant user 404; self 409', async () => {
    const created = (await json(await call('/tenant/users', { method: 'POST', as: insurerB, json: { username: 'sanlam_2', password: strong, displayName: 'S2' } }))).user
    expect((await call(`/tenant/users/${created.id}`, { method: 'PATCH', as: insurerA, json: { status: 'disabled' } })).status).toBe(404)
    expect((await call('/tenant/users/usr_admin_discovery', { method: 'PATCH', as: insurerB, json: { status: 'disabled' } })).status).toBe(404)
    expect((await call('/tenant/users/usr_admin_sanlam', { method: 'PATCH', as: insurerB, json: { status: 'disabled' } })).status).toBe(409)
    const off = await call(`/tenant/users/${created.id}`, { method: 'PATCH', as: insurerB, json: { status: 'disabled' } })
    expect(off.status).toBe(200)
    expect((await login({ username: 'sanlam_2', password: strong })).status).toBe(401)
    expect((await auditRows('tenant.user_status_changed', created.id))[0]).toMatchObject({ actor_tenant_id: 'ins_sanlam' })
  })
})

describe('ACCOUNTS: demo account list stays in sync', () => {
  it('scripts/seed-demo-users.mjs seeds exactly the accounts in src/security/demoUsers.ts', () => {
    const start = seedScript.indexOf('const DEMO_USERS = [')
    const end = seedScript.indexOf(']', start)
    const entries = [...seedScript.slice(start, end).matchAll(/\{[^}]*\}/g)].map((m) => {
      const field = (name: string) => {
        const f = m[0].match(new RegExp(`${name}: (?:'([^']*)'|(null))`))
        return f ? (f[2] ? null : f[1]) : undefined
      }
      return { id: field('id'), username: field('username'), role: field('role'), tenantId: field('tenantId'), displayName: field('displayName') }
    })
    expect(entries).toEqual(DEMO_USERS.map((u) => ({ ...u })))
    expect(DEMO_USERS.map((u) => u.username)).toEqual(['superadmin', 'admin_discovery', 'admin_sanlam', 'mike', 'lerato', 'sipho'])
  })

  it('every demo account can sign in with the demo password', async () => {
    for (const u of DEMO_USERS) {
      const r = await login({ username: u.username, password: PASSWORD })
      expect(r.status, u.username).toBe(200)
      expect(r.body.actor).toMatchObject({ id: u.id, role: u.role, tenantId: u.tenantId, displayName: u.displayName })
    }
  })
})
