import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import { DEMO_PAYOUT, auditRows, call, customerA, customerB, evidenceFile, insurerAdminA, insurerAdminB, managerA, managerB, superadmin } from './helpers'

// The whole journey the Flutter app drives, through the real routes and the real login
// (POST /auth/login with the seeded demo accounts, no minted test tokens). Run twice: with a NORMAL
// and with a HIGH_ANOMALY screening signal. The signal is advisory: HIGH never rejects, and the human
// path completes either way. Final role model: the ASSESSOR prepares the claim, only the MANAGER
// decides and pays; the INSURER_ADMIN and the SUPERADMIN can read it but never move it.

const PASSWORD = env.DEMO_LOGIN_PASSWORD as string

async function signIn(username: string): Promise<string> {
  const res = await call('/auth/login', { method: 'POST', json: { username, password: PASSWORD } })
  expect(res.status).toBe(200)
  return `Bearer ${((await res.json()) as { token: string }).token}`
}

async function api(auth: string, path: string, init: { method?: string; json?: unknown; formData?: FormData } = {}) {
  const res = await call(path, { authorization: auth, ...init })
  const text = await res.text()
  return { status: res.status, body: text ? (JSON.parse(text) as Record<string, any>) : {} }
}

/** Stands in for the offline quantum pipeline import (quantum/results/*.sql); no API writes signals. */
async function importSignal(claimId: string, interpretation: 'NORMAL' | 'HIGH_ANOMALY') {
  const [classical, quantum] = interpretation === 'NORMAL' ? [0.07, 0.05] : [1.0, 1.0]
  await env.DB.prepare(
    `INSERT OR REPLACE INTO screening_signals (claim_id, model_version, classical_anomaly, quantum_anomaly, interpretation, execution, feature_snapshot, computed_at, imported_at)
     VALUES (?, 'phase4-qk1c-v1', ?, ?, ?, 'simulator', '{"days_to_report":{"raw":6,"scaled":0.3}}', '2026-09-26T08:00:00Z', '2026-09-26T08:00:01Z')`
  )
    .bind(claimId, classical, quantum, interpretation)
    .run()
}

describe.each([
  ['NORMAL', 'NORMAL', 'STANDARD_REVIEW'],
  ['HIGH_ANOMALY', 'HIGH', 'REVIEW_REQUIRED'],
] as const)('E2E journey with a %s screening signal', (interpretation, band, recommendation) => {
  it('customer (mike) claims → assessor verifies, screens, reviews → manager decides (ML-DSA signed) → verified → paid → admins read it → audited', async () => {
    // 1. Customer signs in with username + password and sees their own policies with insurer names.
    const customer = await signIn('mike')
    const me = await api(customer, '/auth/me')
    expect(me.body.actor).toMatchObject({ id: 'user123', role: 'CUSTOMER', username: 'mike', displayName: 'Mike' })
    const covers = await api(customer, '/covers/my-covers')
    expect(covers.body.policies).toContainEqual(expect.objectContaining({ id: 'pol_disc_001', insurer_name: expect.any(String) }))

    // 2. Create, describe, set payout details, attach evidence, submit.
    const created = await api(customer, '/claims/initiate', { method: 'POST', json: { policyId: 'pol_disc_001', category: 'Property' } })
    expect(created.status).toBe(201)
    const claimId = created.body.claimId as string
    expect((await api(customer, `/claims/${claimId}/screening`, { method: 'PATCH', json: { causeOfLoss: 'Phone stolen at a taxi rank. SAPS case 123/09/2026.', incidentDate: '2026-09-20' } })).status).toBe(200)
    expect((await api(customer, `/claims/${claimId}/payout-details`, { method: 'PUT', json: DEMO_PAYOUT })).status).toBe(200)
    const form = new FormData()
    form.append('file', evidenceFile())
    const upload = await api(customer, `/claims/${claimId}/evidence`, { method: 'POST', formData: form })
    expect(upload.status).toBe(201)
    expect((await api(customer, `/claims/${claimId}/submit`, { method: 'POST' })).status).toBe(200)

    const detail = await api(customer, `/claims/${claimId}`)
    expect(detail.body.claim).toMatchObject({ id: claimId, stage: 'Submitted', claimedAmountCents: 420_000, payoutDestination: { accountLast4: '7890' } })
    expect(detail.body.claim.user_id).toBeUndefined()

    // 3. The assessor of the same insurer sees it in the queue and prepares it.
    const insurer = await signIn('assessor_discovery')
    expect((await api(insurer, '/auth/me')).body.actor).toMatchObject({ id: 'assessor_a1', role: 'ASSESSOR', tenantId: 'ins_discovery' })
    const queue = await api(insurer, '/claims')
    expect(queue.body.claims).toContainEqual(expect.objectContaining({ id: claimId, stage: 'Submitted', claimed_amount_cents: 420_000 }))
    expect(queue.body.claims[0].user_id).toBeUndefined()
    expect((await api(insurer, `/claims/${claimId}/verify`, { method: 'POST' })).body.to).toBe('Verified')

    await importSignal(claimId, interpretation)
    const screened = await api(insurer, `/claims/${claimId}/screen`, { method: 'POST' })
    expect(screened.status).toBe(200)
    expect(screened.body.to).toBe('Screening')
    expect(screened.body.riskSignals).toMatchObject({ anomalyBand: band, screeningRecommendation: recommendation, advisory: true })
    expect(JSON.stringify(screened.body).toLowerCase()).not.toMatch(/fraud (detected|found|confirmed)|is fraud|rejected/)

    // The signal never moves the claim on its own: still Screening, still Pending.
    expect((await api(customer, `/claims/${claimId}`)).body.claim).toMatchObject({ stage: 'Screening', status: 'Pending' })
    // Customers do not see the screening signal; neither does the platform superadmin.
    expect((await api(customer, `/claims/${claimId}/risk-signals`)).status).toBe(403)
    const platform = await signIn('superadmin')
    expect((await api(platform, `/claims/${claimId}/risk-signals`)).status).toBe(403)

    expect((await api(insurer, `/claims/${claimId}/review`, { method: 'POST' })).body.to).toBe('Review')
    // Separation of duties: the assessor cannot decide.
    expect((await api(insurer, `/claims/${claimId}/decide`, { method: 'POST', json: { outcome: 'Approved', reason: 'x' } })).status).toBe(403)
    // The insurer admin reads the file but cannot decide either.
    const tenantAdmin = await signIn('admin_discovery')
    expect((await api(tenantAdmin, `/claims/${claimId}`)).status).toBe(200)
    expect((await api(tenantAdmin, `/claims/${claimId}/decide`, { method: 'POST', json: { outcome: 'Approved', reason: 'x' } })).status).toBe(403)
    // The platform operator can read the claim but never decides it.
    expect((await api(platform, `/claims/${claimId}`)).status).toBe(200)
    expect((await api(platform, `/claims/${claimId}/decide`, { method: 'POST', json: { outcome: 'Approved', reason: 'x' } })).status).toBe(403)

    // 4. The manager decides; the decision is ML-DSA-65 signed and verifiable by the customer.
    const manager = await signIn('manager_discovery')
    expect((await api(manager, '/auth/me')).body.actor).toMatchObject({ id: 'manager_a1', role: 'MANAGER', tenantId: 'ins_discovery' })
    const decision = await api(manager, `/claims/${claimId}/decide`, { method: 'POST', json: { outcome: 'Approved', reason: 'Evidence verified, within cover' } })
    expect(decision.status).toBe(200)
    expect(decision.body).toMatchObject({ to: 'Decision', outcome: 'Approved', approvedAmountCents: 420_000, integrity: { alg: 'ML-DSA-65' } })
    const verified = await api(customer, `/claims/${claimId}/decision/verify`)
    expect(verified.body.integrity.status).toBe('VALID')
    expect((await api(platform, `/claims/${claimId}/decision/verify`)).body.integrity.status).toBe('VALID')

    // 5. Payout (simulated) at the recorded amount to the recorded destination.
    expect((await api(insurer, `/claims/${claimId}/pay`, { method: 'POST' })).status).toBe(403)
    const paid = await api(manager, `/claims/${claimId}/pay`, { method: 'POST' })
    expect(paid.status).toBe(200)
    expect(paid.body).toMatchObject({ status: 'paid', simulated: true, amountCents: 420_000, destination: { accountLast4: '7890' } })
    const money = await api(customer, `/claims/${claimId}/payout`)
    expect(money.body).toMatchObject({ stage: 'Paid', payout: { amountCents: 420_000, status: 'simulated' } })
    const timeline = await api(customer, `/claims/${claimId}/timeline`)
    expect(timeline.body.timeline.every((s: { completed: boolean }) => s.completed)).toBe(true)
    // The insurer admin and the superadmin see the paid claim read-only.
    expect((await api(tenantAdmin, `/claims/${claimId}`)).body.claim).toMatchObject({ stage: 'Paid' })
    expect((await api(tenantAdmin, `/claims/${claimId}/payout`)).body).toMatchObject({ payout: { amountCents: 420_000 } })
    expect((await api(platform, `/claims/${claimId}`)).body.claim).toMatchObject({ stage: 'Paid' })
    const decidedBy = (await api(customer, `/claims/${claimId}/decision`)).body.record
    expect(decidedBy).toMatchObject({ decidedByRole: 'MANAGER' })

    // 6. Audit trail covers every consequential step, including the sign-ins.
    for (const action of ['auth.login', 'claim.created', 'claim.screening_updated', 'claim.payout_details_set', 'screening.signal_attached', 'claim.decision_recorded', 'payout.completed_simulated']) {
      expect((await auditRows(action)).length, action).toBeGreaterThan(0)
    }
    const stages = (await auditRows('claim.stage_changed', claimId)).map((r) => JSON.parse(r.details as string).to)
    expect(stages).toEqual(['Submitted', 'Verified', 'Screening', 'Review', 'Decision', 'Paid'])
    const evidenceRows = await env.DB.prepare("SELECT count(*) AS n FROM audit_events WHERE action = 'evidence.uploaded'").first<{ n: number }>()
    expect(evidenceRows!.n).toBeGreaterThan(0)
    const logins = await auditRows('auth.login')
    expect(JSON.stringify(logins)).not.toContain(PASSWORD)
  })
})

describe('claim detail route', () => {
  it('owner, tenant staff, tenant insurer admin and superadmin read it; other customer and other tenant get 404; no token 401', async () => {
    const own = await call('/claims/claim_disc_101', { as: customerA })
    expect(own.status).toBe(200)
    expect(((await own.json()) as any).claim).toMatchObject({ id: 'claim_disc_101', stage: 'Review', insurerName: expect.any(String), planName: 'Discovery Health Executive Plan' })
    expect((await call('/claims/claim_disc_101', { as: customerB })).status).toBe(404)
    expect((await call('/claims/claim_disc_101', { as: managerB })).status).toBe(404)
    expect((await call('/claims/claim_disc_101', { as: managerA })).status).toBe(200)
    expect((await call('/claims/claim_disc_101', { as: insurerAdminA })).status).toBe(200)
    expect((await call('/claims/claim_disc_101', { as: insurerAdminB })).status).toBe(404)
    expect((await call('/claims/claim_disc_101', { as: superadmin })).status).toBe(200)
    expect((await call('/claims/claim_disc_101')).status).toBe(401)
  })
})
