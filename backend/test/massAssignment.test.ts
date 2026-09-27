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
    { tenantId: 'ins_sanlam' },
    { tenant_id: 'ins_sanlam' },
  ])('screening rejects privileged field %o', async (extra) => {
    const claimId = await newDraft()
    const res = await call(`/claims/${claimId}/screening`, {
      method: 'PATCH',
      as: customerA,
      json: { causeOfLoss: 'Accident', incidentDate: '2026-01-10', ...extra },
    })
    expect(res.status).toBe(400)
    const row = await env.DB.prepare('SELECT stage, status, user_id, tenant_id FROM claims WHERE id = ?').bind(claimId).first()
    expect(row).toEqual({ stage: 'Draft', status: 'Pending', user_id: 'user123', tenant_id: 'ins_discovery' })
  })

  it.each([
    { stage: 'Paid', userId: 'user456' },
    { tenantId: 'ins_sanlam' },
    { tenant_id: 'ins_sanlam' },
  ])('initiate rejects client-set %o', async (extra) => {
    const res = await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001', ...extra } })
    expect(res.status).toBe(400)
  })

  it('initiate derives tenant_id from the policy, never from the request', async () => {
    const claimId = await newDraft()
    const row = await env.DB.prepare('SELECT tenant_id FROM claims WHERE id = ?').bind(claimId).first()
    expect(row).toEqual({ tenant_id: 'ins_discovery' })
  })

  it('link-request refuses a client-supplied userId (the customer comes from the token)', async () => {
    const bad = await call('/covers/link-requests', {
      method: 'POST',
      as: customerA,
      json: { tenantId: 'ins_discovery', policyNumber: 'DH-MASS-1', userId: 'user456' },
    })
    expect(bad.status).toBe(400)
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
