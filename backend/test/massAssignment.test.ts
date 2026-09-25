import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import { call, customerA } from './helpers'

async function newDraft() {
  const res = await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001' } })
  return ((await res.json()) as { claimId: string }).claimId
}

describe('object property authorization (mass assignment)', () => {
  it.each([
    { stage: 'Paid' },
    { status: 'Approved' },
    { riskScore: 0 },
    { decision: 'approve' },
    { approvedBy: 'manager1' },
    { user_id: 'user456' },
  ])('screening rejects privileged field %o', async (extra) => {
    const claimId = await newDraft()
    const res = await call(`/claims/${claimId}/screening`, {
      method: 'PATCH',
      as: customerA,
      json: { causeOfLoss: 'Accident', incidentDate: '2026-01-10', ...extra },
    })
    expect(res.status).toBe(400)
    const row = await env.DB.prepare('SELECT stage, status, user_id FROM claims WHERE id = ?').bind(claimId).first()
    expect(row).toEqual({ stage: 'Draft', status: 'Pending', user_id: 'user123' })
  })

  it('initiate rejects client-set stage/userId', async () => {
    const res = await call('/claims/initiate', {
      method: 'POST',
      as: customerA,
      json: { policyId: 'pol_disc_001', stage: 'Paid', userId: 'user456' },
    })
    expect(res.status).toBe(400)
  })

  it('join-request rejects a client-supplied userId and does not echo the body', async () => {
    const bad = await call('/covers/join-request', {
      method: 'POST',
      as: customerA,
      json: { planId: 'cat_02', userId: 'user456' },
    })
    expect(bad.status).toBe(400)

    const good = await call('/covers/join-request', { method: 'POST', as: customerA, json: { planId: 'cat_02' } })
    expect(good.status).toBe(200)
    const body = (await good.json()) as Record<string, unknown>
    expect(body).not.toHaveProperty('body')
    expect(body).toMatchObject({ planId: 'cat_02', provider: 'Sanlam' })
  })

  it('validation errors do not echo submitted values', async () => {
    const claimId = await newDraft()
    const res = await call(`/claims/${claimId}/screening`, {
      method: 'PATCH',
      as: customerA,
      json: { causeOfLoss: '<script>alert(1)</script>', incidentDate: '2999-01-01' },
    })
    expect(res.status).toBe(400)
    expect(await res.text()).not.toContain('<script>')
  })
})
