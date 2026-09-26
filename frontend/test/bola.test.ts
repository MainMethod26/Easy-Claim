import { describe, expect, it } from 'vitest'
import { assessor, auditRows, call, customerA, customerB } from './helpers'

describe('object-level authorization (IDOR/BOLA)', () => {
  it("customer B cannot read customer A's claim timeline", async () => {
    const res = await call('/claims/claim_disc_101/timeline', { as: customerB })
    expect(res.status).toBe(404)
    const body = await res.text()
    expect(body).not.toContain('user123')
    expect(body).not.toContain('pol_disc_001')
  })

  it("customer B cannot read customer A's decision", async () => {
    expect((await call('/claims/claim_sanlam_102/decision', { as: customerB })).status).toBe(404)
  })

  it("customer B cannot submit, screen, upload evidence to, or appeal customer A's claim", async () => {
    const id = 'claim_disc_101'
    expect((await call(`/claims/${id}/submit`, { method: 'POST', as: customerB })).status).toBe(404)
    expect((await call(`/claims/${id}/evidence-ocr`, { method: 'POST', as: customerB })).status).toBe(404)
    const screening = await call(`/claims/${id}/screening`, {
      method: 'PATCH',
      as: customerB,
      json: { causeOfLoss: 'x', incidentDate: '2026-01-01' },
    })
    expect(screening.status).toBe(404)
    const appeal = await call(`/claims/${id}/appeal`, { method: 'POST', as: customerB, json: { reason: 'x' } })
    expect(appeal.status).toBe(404)
  })

  it('denied and non-existent claims look identical (no existence oracle)', async () => {
    const denied = await call('/claims/claim_disc_101/timeline', { as: customerB })
    const missing = await call('/claims/claim_does_not_exist/timeline', { as: customerB })
    expect(denied.status).toBe(missing.status)
    expect(await denied.json()).toEqual(await missing.json())
  })

  it('records a security event for the denied access', async () => {
    await call('/claims/claim_disc_101/timeline', { as: customerB })
    const rows = await auditRows('authz.claim_access_denied', 'claim_disc_101')
    expect(rows.length).toBeGreaterThan(0)
    expect(rows[0]).toMatchObject({ actor_id: 'user456', outcome: 'denied' })
  })

  it('owner can read their own claim', async () => {
    const res = await call('/claims/claim_disc_101/timeline', { as: customerA })
    expect(res.status).toBe(200)
    expect(await res.json()).toMatchObject({ claimId: 'claim_disc_101', currentStage: 'Review' })
  })

  it('insurer staff can read, but not act as the customer', async () => {
    expect((await call('/claims/claim_disc_101/timeline', { as: assessor })).status).toBe(200)
    expect((await call('/claims/claim_disc_101/submit', { method: 'POST', as: assessor })).status).toBe(403)
  })

  it("my-covers returns only the caller's policies", async () => {
    const res = await call('/covers/my-covers', { as: customerB })
    const { policies } = (await res.json()) as { policies: { user_id: string }[] }
    expect(policies.length).toBeGreaterThan(0)
    expect(policies.every((p) => p.user_id === 'user456')).toBe(true)
  })

  it("customer cannot start a claim on someone else's policy", async () => {
    const res = await call('/claims/initiate', { method: 'POST', as: customerB, json: { policyId: 'pol_disc_001' } })
    expect(res.status).toBe(422)
  })

  it("verify-eligibility does not confirm someone else's policy", async () => {
    const res = await call('/claims/verify-eligibility', {
      method: 'POST',
      as: customerB,
      json: { policyId: 'pol_disc_001' },
    })
    expect(await res.json()).toMatchObject({ verified: false })
  })
})
