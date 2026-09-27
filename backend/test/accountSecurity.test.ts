import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import { auditRows, call, createSubmittedClaim, customerA, insurerAdminA, mintToken } from './helpers'

// Hardening (migration 0014): accounts are re-checked on every request, sessions can be revoked,
// passwords can be changed, repeated wrong passwords lock the account, the public insurer form is
// throttled per address, claim lists page, and audit rows carry no banking digits.

async function json(res: Response) {
  return (await res.json()) as Record<string, any>
}

async function register(username: string, password = 'first-pass-123') {
  const r = await call('/auth/register', { method: 'POST', json: { username, password, displayName: username } })
  expect(r.status).toBe(201)
  return (await json(r)) as { token: string; actor: { id: string } }
}

describe('accounts are re-checked on every request', () => {
  it('SEC-01 a disabled staff account is refused at once, not when its token expires', async () => {
    const created = await json(
      await call('/tenant/users', { method: 'POST', as: insurerAdminA, json: { username: 'temp_assessor', password: 'temp-pass-123', displayName: 'Temp', role: 'ASSESSOR' } })
    )
    const login = await json(await call('/auth/login', { method: 'POST', json: { username: 'temp_assessor', password: 'temp-pass-123' } }))
    const auth = `Bearer ${login.token}`
    expect((await call('/claims', { authorization: auth })).status).toBe(200)
    expect((await call(`/tenant/users/${created.user.id}`, { method: 'PATCH', as: insurerAdminA, json: { status: 'disabled' } })).status).toBe(200)
    expect((await call('/claims', { authorization: auth })).status).toBe(401)
    // Re-enabling does not bring the old token back: a new sign-in is needed.
    await call(`/tenant/users/${created.user.id}`, { method: 'PATCH', as: insurerAdminA, json: { status: 'active' } })
    expect((await call('/claims', { authorization: auth })).status).toBe(401)
    const again = await json(await call('/auth/login', { method: 'POST', json: { username: 'temp_assessor', password: 'temp-pass-123' } }))
    expect((await call('/claims', { authorization: `Bearer ${again.token}` })).status).toBe(200)
  })

  it('SEC-02 a token whose role or insurer no longer matches the account is refused', async () => {
    const forgedRole = await mintToken({ id: 'user123', role: 'ASSESSOR', tenantId: 'ins_discovery' })
    expect((await call('/claims', { authorization: `Bearer ${forgedRole}` })).status).toBe(401)
    const wrongTenant = await mintToken({ id: 'usr_admin_discovery', role: 'INSURER_ADMIN', tenantId: 'ins_sanlam' })
    expect((await call('/tenant', { authorization: `Bearer ${wrongTenant}` })).status).toBe(401)
  })
})

describe('password change', () => {
  it('SEC-10 needs the current password, revokes other sessions and returns a fresh one', async () => {
    const s = await register('pw_changer')
    const old = `Bearer ${s.token}`
    expect((await call('/auth/password', { method: 'POST', authorization: old, json: { currentPassword: 'wrong', newPassword: 'second-pass-456' } })).status).toBe(401)
    expect((await call('/auth/password', { method: 'POST', authorization: old, json: { currentPassword: 'first-pass-123', newPassword: 'short' } })).status).toBe(400)
    const r = await call('/auth/password', { method: 'POST', authorization: old, json: { currentPassword: 'first-pass-123', newPassword: 'second-pass-456' } })
    expect(r.status).toBe(200)
    const fresh = `Bearer ${(await json(r)).token}`
    expect((await call('/covers/my-covers', { authorization: old })).status).toBe(401)
    expect((await call('/covers/my-covers', { authorization: fresh })).status).toBe(200)
    expect((await call('/auth/login', { method: 'POST', json: { username: 'pw_changer', password: 'first-pass-123' } })).status).toBe(401)
    expect((await call('/auth/login', { method: 'POST', json: { username: 'pw_changer', password: 'second-pass-456' } })).status).toBe(200)
    const rows = await auditRows('auth.password_change', s.actor.id)
    expect(rows.map((x) => x.outcome).sort()).toEqual(['denied', 'success'])
    expect(JSON.stringify(rows)).not.toContain('second-pass-456')
  })
})

describe('login lockout', () => {
  it('SEC-20 five wrong passwords lock the account for a while, even for the right password', async () => {
    await register('lock_me', 'right-pass-123')
    for (let i = 0; i < 5; i++) {
      expect((await call('/auth/login', { method: 'POST', json: { username: 'lock_me', password: `wrong-${i}` } })).status).toBe(401)
    }
    const locked = await call('/auth/login', { method: 'POST', json: { username: 'lock_me', password: 'right-pass-123' } })
    expect(locked.status).toBe(429)
    expect(await locked.json()).toEqual({ error: 'too_many_attempts' })
    expect((await auditRows('auth.login_locked')).length).toBeGreaterThan(0)
    // Other accounts are unaffected.
    expect((await call('/auth/login', { method: 'POST', json: { username: 'mike', password: env.DEMO_LOGIN_PASSWORD } })).status).toBe(200)
  })
})

describe('public insurer form throttle', () => {
  it('SEC-30 at most three applications per address per day; the address is stored only as a hash', async () => {
    const apply = (i: number) =>
      call('/auth/insurer-applications', {
        method: 'POST',
        headers: { 'cf-connecting-ip': '203.0.113.7' },
        json: { companyName: `Co ${i}`, fspNumber: `55${i}`, contactEmail: `c${i}@example.com`, adminUsername: `ip_admin_${i}`, adminDisplayName: 'Admin', password: 'apply-pass-1' },
      })
    for (let i = 0; i < 3; i++) expect((await apply(i)).status).toBe(201)
    const fourth = await apply(3)
    expect(fourth.status).toBe(429)
    expect(await fourth.json()).toEqual({ error: 'too_many_applications' })
    const rows = await env.DB.prepare("SELECT ip_hash FROM insurer_applications WHERE admin_username LIKE 'ip_admin_%'").all<{ ip_hash: string }>()
    expect(rows.results.every((r) => /^[0-9a-f]{64}$/.test(r.ip_hash))).toBe(true)
    expect(JSON.stringify(rows.results)).not.toContain('203.0.113.7')
  })
})

describe('claim lists and audit hygiene', () => {
  it('SEC-40 claim lists page with a cursor and filter by stage', async () => {
    for (let i = 0; i < 3; i++) await createSubmittedClaim()
    const first = await json(await call('/claims?limit=2', { as: customerA }))
    expect(first.claims).toHaveLength(2)
    expect(first.nextBefore).toEqual(expect.stringContaining('|'))
    const second = await json(await call(`/claims?limit=2&before=${encodeURIComponent(first.nextBefore)}`, { as: customerA }))
    const ids = new Set([...first.claims, ...second.claims].map((c: { id: string }) => c.id))
    expect(ids.size).toBe(first.claims.length + second.claims.length) // no overlap between pages
    const submitted = await json(await call('/claims?stage=Submitted&limit=50', { as: customerA }))
    expect(submitted.claims.length).toBeGreaterThanOrEqual(3)
    expect(submitted.claims.every((c: { stage: string }) => c.stage === 'Submitted')).toBe(true)
    expect((await call('/claims?stage=Nope', { as: customerA })).status).toBe(400)
    expect((await call('/claims?before=bad', { as: customerA })).status).toBe(400)
  })

  it('SEC-41 audit rows never carry bank account digits', async () => {
    const id = await createSubmittedClaim()
    const rows = await auditRows('claim.payout_details_set')
    expect(rows.length).toBeGreaterThan(0)
    for (const r of rows) expect(JSON.stringify(r)).not.toMatch(/destinationLast4|\b7890\b/)
    expect(id).toBeTruthy()
  })
})
