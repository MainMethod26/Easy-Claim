import { env } from 'cloudflare:workers'
import { beforeAll, describe, expect, it } from 'vitest'
import { assessorB, auditRows, call, customerA, insurerAdminA as insurerA, insurerAdminB as insurerB, managerA, superadmin } from './helpers'

// Read-only admin dashboards (src/admin/metrics.ts, docs/admin/METRICS.md).
// Ledger rows are inserted directly so the arithmetic of every metric is asserted exactly,
// independent of which staff role performs decide/pay.

const H = 3_600_000
const iso = (msAgo: number) => new Date(Date.now() - msAgo).toISOString()

beforeAll(async () => {
  const claim = (id: string, stage: string, tenant: string, createdMsAgo: number) =>
    env.DB.prepare(
      `INSERT INTO claims (id, user_id, policy_id, stage, status, tenant_id, created_at, payout_bank_name, payout_account_last4)
       VALUES (?, 'user123', 'pol_disc_001', ?, 'x', ?, ?, 'SecretBank', '9876')`
    ).bind(id, stage, tenant, iso(createdMsAgo))
  const decision = (id: string, claimId: string, tenant: string, outcome: string, decidedMsAgo: number, signed: boolean) =>
    env.DB.prepare(
      `INSERT INTO claim_decisions (id, claim_id, tenant_id, outcome, reason, previous_stage, actor_id, actor_role, decided_at, rules_version, integrity_alg, integrity_key_id)
       VALUES (?, ?, ?, ?, 'r', 'Review', 'usr_x', 'MANAGER', ?, 'v1', ?, ?)`
    ).bind(id, claimId, tenant, outcome, iso(decidedMsAgo), signed ? 'ML-DSA-65' : null, signed ? 'mldsa65-test' : null)
  const signal = (claimId: string, interpretation: string) =>
    env.DB.prepare(
      `INSERT INTO screening_signals (claim_id, model_version, classical_anomaly, quantum_anomaly, interpretation, execution, computed_at)
       VALUES (?, 'phase4-qk1c-v1', 0.5, 0.5, ?, 'simulator', '2026-09-26T00:00:00Z')`
    ).bind(claimId, interpretation)

  await env.DB.batch([
    claim('claim_m1', 'Paid', 'ins_discovery', 48 * H),
    claim('claim_m2', 'Decision', 'ins_discovery', 10 * H),
    claim('claim_m4', 'Draft', 'ins_discovery', 1 * H),
    claim('claim_m5', 'Withdrawn', 'ins_discovery', 500 * 24 * H),
    decision('dec_m1', 'claim_m1', 'ins_discovery', 'Approved', 24 * H, true),
    decision('dec_m2', 'claim_m2', 'ins_discovery', 'Rejected', 4 * H, false),
    decision('dec_m5', 'claim_m5', 'ins_discovery', 'Approved', 400 * 24 * H, false),
    decision('dec_s1', 'claim_sanlam_102', 'ins_sanlam', 'Approved', 1 * H, false),
    env.DB.prepare(
      `INSERT INTO payouts (id, claim_id, tenant_id, decision_id, amount_cents, destination_hash, destination_last4, status, initiated_by, initiated_role, initiated_at)
       VALUES ('pay_m1', 'claim_m1', 'ins_discovery', 'dec_m1', 100000, 'h', '9876', 'simulated', 'usr_x', 'MANAGER', ?)`
    ).bind(iso(20 * H)),
    signal('claim_m1', 'NORMAL'),
    signal('claim_disc_101', 'UNUSUAL'),
    signal('claim_m2', 'HIGH_ANOMALY'),
    signal('claim_m4', 'HIGH_ANOMALY'), // draft: never counted
    signal('claim_sanlam_102', 'HIGH_ANOMALY'),
  ])
})

async function json<T>(res: Response): Promise<T> {
  expect(res.status).toBe(200)
  return (await res.json()) as T
}

describe('access to admin dashboards', () => {
  it('ADM-01 platform dashboards are SUPERADMIN only; tenant dashboards INSURER_ADMIN only', async () => {
    for (const path of ['/admin/overview', '/admin/security', '/admin/integrity', '/admin/audit']) {
      expect((await call(path)).status).toBe(401)
      expect((await call(path, { as: customerA })).status).toBe(403)
      expect((await call(path, { as: insurerA })).status).toBe(403)
      expect((await call(path, { as: superadmin })).status).toBe(200)
    }
    for (const path of ['/tenant/overview', '/tenant/audit']) {
      expect((await call(path)).status).toBe(401)
      expect((await call(path, { as: customerA })).status).toBe(403)
      expect((await call(path, { as: superadmin })).status).toBe(403)
      expect((await call(path, { as: insurerA })).status).toBe(200)
    }
  })

  it('ADM-02 an insurer admin cannot choose another tenant: tenantId in the query is rejected (400)', async () => {
    expect((await call('/tenant/overview?tenantId=ins_sanlam', { as: insurerA })).status).toBe(400)
    expect((await call('/tenant/audit?tenantId=ins_sanlam', { as: insurerA })).status).toBe(400)
  })

  it('ADM-03 bounded inputs: window 1..365 days, page 1..100, action filter cannot carry LIKE wildcards', async () => {
    expect((await call('/admin/overview?days=0', { as: superadmin })).status).toBe(400)
    expect((await call('/admin/overview?days=366', { as: superadmin })).status).toBe(400)
    expect((await call('/admin/audit?limit=101', { as: superadmin })).status).toBe(400)
    expect((await call('/admin/audit?action=%25', { as: superadmin })).status).toBe(400)
    expect((await call('/admin/audit?before=yesterday', { as: superadmin })).status).toBe(400)
  })
})

describe('tenant overview (INSURER_ADMIN)', () => {
  it('ADM-10 counts only its own tenant, from real rows, with documented definitions', async () => {
    const o = await json<Record<string, any>>(await call('/tenant/overview', { as: insurerA }))
    expect(o.tenant).toEqual({ id: 'ins_discovery', name: 'Discovery Health' })
    // lodged = disc_101 (Review), m1 (Paid), m2 (Decision), m5 (Withdrawn); the draft m4 is excluded
    expect(o.claims).toMatchObject({ total: 4, open: 2 })
    expect(o.claims.byStage).toMatchObject({ Review: 1, Paid: 1, Decision: 1, Withdrawn: 1, Submitted: 0 })
    expect(o.claims.byStage.Draft).toBeUndefined()
    // 30-day window: m1 Approved (24 h after creation), m2 Rejected (6 h); m5 is 400 days old; Sanlam excluded
    expect(o.decisions).toEqual({ windowDays: 30, approved: 1, rejected: 1, approvalRate: 0.5, medianHoursToDecision: 15 })
    expect(o.payouts).toEqual({ windowDays: 30, count: 1, totalCents: 100000 })
    expect(o.screening).toEqual({ NORMAL: 1, ELEVATED: 1, HIGH: 1, unscreened: 1 })
    expect(o.integrity).toMatchObject({ signed: 1, unsigned: 2 })
    expect(o.staff).toEqual({ byRole: { INSURER_ADMIN: 1, ASSESSOR: 1, MANAGER: 1 }, active: 3, disabled: 0 })
  })

  it('ADM-11 the window parameter changes only windowed metrics', async () => {
    const o = await json<Record<string, any>>(await call('/tenant/overview?days=365', { as: insurerA }))
    expect(o.decisions).toMatchObject({ windowDays: 365, approved: 1, rejected: 1 })
    expect(o.claims.total).toBe(4)
  })

  it('ADM-12 the other tenant sees its own numbers, not tenant A', async () => {
    const o = await json<Record<string, any>>(await call('/tenant/overview', { as: insurerB }))
    expect(o.tenant.id).toBe('ins_sanlam')
    expect(o.claims).toMatchObject({ total: 1, open: 1 })
    expect(o.decisions).toMatchObject({ approved: 1, rejected: 0, approvalRate: 1 })
    expect(o.payouts.count).toBe(0)
    expect(o.screening).toEqual({ NORMAL: 0, ELEVATED: 0, HIGH: 1, unscreened: 0 })
  })

  it('ADM-13 no sensitive fields in any dashboard response', async () => {
    const bodies = await Promise.all(
      [
        call('/tenant/overview', { as: insurerA }),
        call('/tenant/audit', { as: insurerA }),
        call('/admin/overview', { as: superadmin }),
        call('/admin/security', { as: superadmin }),
        call('/admin/integrity', { as: superadmin }),
        call('/admin/audit', { as: superadmin }),
      ].map(async (p) => (await p).text())
    )
    for (const b of bodies) {
      for (const secret of ['SecretBank', '9876', 'password', 'payout_account', 'destination_hash', 'details']) {
        expect(b).not.toContain(secret)
      }
    }
    // Insurer views never reveal a customer's account id; the platform audit may (operator investigations).
    expect(bodies[0]).not.toContain('user123')
    expect(bodies[1]).not.toContain('user123')
  })
})

describe('audit log views', () => {
  it('ADM-20 tenant audit is scoped: own events and events on own claims; another tenant is invisible', async () => {
    // A Tenant B assessor probes a tenant A claim (denied, audited on the claim) ...
    expect((await call('/claims/claim_disc_101/timeline', { as: assessorB })).status).toBe(404)
    // ... and a Tenant B account signs in (audited on the Sanlam user only).
    await call('/auth/login', { method: 'POST', json: { username: 'admin_sanlam', password: env.DEMO_LOGIN_PASSWORD } })

    const a = await json<{ events: Record<string, any>[] }>(await call('/tenant/audit?limit=100', { as: insurerA }))
    const probe = a.events.find((e) => e.action === 'authz.claim_access_denied' && e.resourceId === 'claim_disc_101')
    // Tenant A sees the probe on its claim, but not who from the other tenant made it.
    expect(probe).toMatchObject({ outcome: 'denied', actorRole: 'ASSESSOR', actorId: null })
    expect(a.events.some((e) => e.resourceId === 'usr_admin_sanlam')).toBe(false)

    const b = await json<{ events: Record<string, any>[] }>(await call('/tenant/audit?limit=100', { as: insurerB }))
    expect(b.events.some((e) => e.action === 'auth.login' && e.resourceId === 'usr_admin_sanlam')).toBe(true)
    expect(b.events.some((e) => e.resourceId === 'claim_disc_101' && e.action !== 'authz.claim_access_denied')).toBe(false)
    // The probing tenant sees its own actor id on its own event.
    expect(b.events.find((e) => e.action === 'authz.claim_access_denied')).toMatchObject({ actorId: 'assessor_b1' })
  })

  it('ADM-21 paging is newest-first with a cursor, and filters apply', async () => {
    const first = await json<{ events: { occurredAt: string }[]; nextBefore: string | null }>(
      await call('/admin/audit?limit=2', { as: superadmin })
    )
    expect(first.events).toHaveLength(2)
    expect(first.nextBefore).toBe(first.events[1].occurredAt)
    const next = await json<{ events: { occurredAt: string }[] }>(
      await call(`/admin/audit?limit=2&before=${encodeURIComponent(first.nextBefore as string)}`, { as: superadmin })
    )
    for (const e of next.events) expect(e.occurredAt < (first.nextBefore as string)).toBe(true)

    const denied = await json<{ events: { outcome: string; action: string }[] }>(
      await call('/admin/audit?outcome=denied&action=authz.', { as: superadmin })
    )
    expect(denied.events.length).toBeGreaterThan(0)
    for (const e of denied.events) {
      expect(e.outcome).toBe('denied')
      expect(e.action.startsWith('authz.')).toBe(true)
    }
    const oneTenant = await json<{ events: { resourceId: string }[] }>(await call('/admin/audit?tenantId=ins_sanlam&limit=100', { as: superadmin }))
    expect(oneTenant.events.some((e) => e.resourceId === 'usr_admin_sanlam')).toBe(true)
  })

  it('ADM-22 reading the audit log is itself audited', async () => {
    await call('/tenant/audit', { as: insurerA })
    await call('/admin/audit?outcome=denied', { as: superadmin })
    expect((await auditRows('tenant.audit_viewed', 'ins_discovery')).length).toBeGreaterThan(0)
    const rows = await auditRows('admin.audit_viewed', 'platform')
    expect(rows.length).toBeGreaterThan(0)
    expect(JSON.parse(rows[rows.length - 1].details as string)).toMatchObject({ outcome: 'denied' })
  })
})

describe('platform dashboards (SUPERADMIN)', () => {
  it('ADM-30 overview: per-tenant summary and platform totals', async () => {
    const o = await json<Record<string, any>>(await call('/admin/overview', { as: superadmin }))
    expect(o.tenants).toBe(5)
    const disc = o.perTenant.find((t: any) => t.id === 'ins_discovery')
    expect(disc).toMatchObject({ name: 'Discovery Health', claims: 4, openClaims: 2, staff: 3, activeAdmins: 1, decisionsInWindow: 2, payoutsInWindow: 1 })
    expect(o.claims.total).toBe(6) // 4 Discovery + 1 Sanlam + 1 Momentum
    expect(o.decisions).toMatchObject({ approved: 2, rejected: 1 })
    expect(o.usersByRole).toMatchObject({ SUPERADMIN: 1, CUSTOMER: 3 })
  })

  it('ADM-31 security: logins, denials by action, and what is not measured', async () => {
    await call('/auth/login', { method: 'POST', json: { username: 'mike', password: 'wrong-password' } })
    const s = await json<Record<string, any>>(await call('/admin/security', { as: superadmin }))
    expect(s.logins.denied).toBeGreaterThanOrEqual(1)
    expect(s.deniedByAction.map((r: any) => r.action)).toContain('authz.role_denied')
    expect(s.recentDenied.every((e: any) => e.outcome === 'denied')).toBe(true)
    expect(s.notMeasured.length).toBeGreaterThan(0)
  })

  it('ADM-32 integrity: signed vs unsigned decisions, key ids, verifications, screening execution', async () => {
    await call('/claims/claim_m1/decision/verify', { as: managerA })
    const i = await json<Record<string, any>>(await call('/admin/integrity', { as: superadmin }))
    expect(i.decisions).toEqual({ total: 4, signed: 1, unsigned: 3, byKeyId: [{ keyId: 'mldsa65-test', count: 1 }] })
    const verified = Object.values(i.verificationsInWindow as Record<string, number>).reduce((a, b) => a + b, 0)
    expect(verified).toBe(1)
    expect(i.screening).toMatchObject({ NORMAL: 1, ELEVATED: 1, HIGH: 2, unscreened: 2, byExecution: { simulator: 5 } })
    expect(i.screening.byExecution.hardware).toBeUndefined()
  })
})
