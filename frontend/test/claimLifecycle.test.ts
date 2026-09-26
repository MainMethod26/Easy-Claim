import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import { auditRows, call, createReadyDraft, customerA } from './helpers'

describe('claim lifecycle over the API', () => {
  it('initiate -> screening -> submit follows the state machine and is audited', async () => {
    const claimId = await createReadyDraft()
    expect(claimId).toMatch(/^claim_[0-9a-f-]{36}$/)

    const res = await call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA })
    expect(res.status).toBe(200)
    const row = await env.DB.prepare('SELECT stage FROM claims WHERE id = ?').bind(claimId).first()
    expect(row).toEqual({ stage: 'Submitted' })
    expect(await auditRows('claim.created', claimId)).toHaveLength(1)
    expect(await auditRows('claim.stage_changed', claimId)).toHaveLength(1)

    const timeline = (await (await call(`/claims/${claimId}/timeline`, { as: customerA })).json()) as {
      timeline: { stage: string; completed: boolean; date: string | null }[]
    }
    expect(timeline.timeline[0]).toMatchObject({ stage: 'Submitted', completed: true })
    expect(timeline.timeline[0].date).not.toBeNull()
    expect(timeline.timeline[1]).toMatchObject({ stage: 'Verified', completed: false })
  })

  it('cannot submit before screening is complete', async () => {
    const init = await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001' } })
    const { claimId } = (await init.json()) as { claimId: string }
    expect((await call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA })).status).toBe(422)
  })

  it('double submit is rejected (replay)', async () => {
    const claimId = await createReadyDraft()
    expect((await call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA })).status).toBe(200)
    expect((await call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA })).status).toBe(409)
    expect(await auditRows('claim.transition_rejected', claimId)).toHaveLength(1)
  })

  it('a claim already in Review cannot be re-submitted or edited by the customer', async () => {
    expect((await call('/claims/claim_disc_101/submit', { method: 'POST', as: customerA })).status).toBe(409)
    const edit = await call('/claims/claim_disc_101/screening', {
      method: 'PATCH',
      as: customerA,
      json: { causeOfLoss: 'changed story', incidentDate: '2026-01-01' },
    })
    expect(edit.status).toBe(409)
  })

  it('an approved decision cannot be appealed', async () => {
    const res = await call('/claims/claim_sanlam_102/appeal', { method: 'POST', as: customerA, json: { reason: 'x' } })
    expect(res.status).toBe(409)
  })

  it('a rejected decision can be appealed exactly once', async () => {
    await env.DB.prepare(
      "INSERT INTO claims (id, user_id, policy_id, stage, status) VALUES ('claim_rej_1', 'user123', 'pol_disc_001', 'Decision', 'Rejected')"
    ).run()
    const first = await call('/claims/claim_rej_1/appeal', { method: 'POST', as: customerA, json: { reason: 'New evidence' } })
    expect(first.status).toBe(200)
    const second = await call('/claims/claim_rej_1/appeal', { method: 'POST', as: customerA, json: { reason: 'Again' } })
    expect(second.status).toBe(409)
  })

  it('cannot initiate a claim on a non-active policy', async () => {
    await env.DB.prepare(
      "INSERT INTO policies (id, user_id, plan_name, status) VALUES ('pol_lapsed', 'user123', 'Lapsed Plan', 'Lapsed')"
    ).run()
    const res = await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_lapsed' } })
    expect(res.status).toBe(422)
  })
})
