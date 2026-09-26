import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import { assessorA, assessorB, call, claimStage, createSubmittedClaim, customerA } from './helpers'

// Phase 4 (quantum track). The advisory signal is read-only screening context. These tests
// prove the boundary: it inherits auth/tenant/ownership, no client can write it, and it
// cannot move a claim.

async function insertSignal(claimId: string, quantum = 0.97, interpretation = 'HIGH_ANOMALY') {
  await env.DB.prepare(
    `INSERT OR REPLACE INTO screening_signals (claim_id, model_version, classical_anomaly, quantum_anomaly, interpretation, execution, feature_snapshot, computed_at)
     VALUES (?, 'test-model', 0.42, ?, ?, 'simulator', '{}', '2026-09-26T00:00:00Z')`
  )
    .bind(claimId, quantum, interpretation)
    .run()
}

async function verifiedClaim(): Promise<string> {
  const claimId = await createSubmittedClaim()
  const res = await call(`/claims/${claimId}/verify`, { method: 'POST', as: assessorA })
  if (res.status !== 200) throw new Error(`verify failed: ${res.status}`)
  return claimId
}

describe('screening signals (Phase 4, advisory only)', () => {
  it('/screen returns riskSignals: null when nothing has been computed, and still transitions', async () => {
    const claimId = await verifiedClaim()
    const res = await call(`/claims/${claimId}/screen`, { method: 'POST', as: assessorA })
    expect(res.status).toBe(200)
    const body = (await res.json()) as { to: string; riskSignals: unknown }
    expect(body.to).toBe('Screening')
    expect(body.riskSignals).toBeNull()
    expect((await claimStage(claimId))?.stage).toBe('Screening')
  })

  it('/screen attaches the stored signal with an explanation and advisory flag', async () => {
    const claimId = await verifiedClaim()
    await insertSignal(claimId)
    const res = await call(`/claims/${claimId}/screen`, { method: 'POST', as: assessorA })
    expect(res.status).toBe(200)
    const { riskSignals } = (await res.json()) as { riskSignals: Record<string, unknown> }
    expect(riskSignals).toMatchObject({
      classicalAnomaly: 0.42,
      quantumAnomaly: 0.97,
      interpretation: 'HIGH_ANOMALY',
      execution: 'simulator',
      advisory: true,
    })
    expect(String(riskSignals.explanation)).toContain('not a fraud finding')
  })

  it('a HIGH_ANOMALY signal does not change the stage, status or anything else on the claim', async () => {
    const claimId = await verifiedClaim()
    const before = await env.DB.prepare('SELECT * FROM claims WHERE id = ?').bind(claimId).first()
    await insertSignal(claimId, 1.0, 'HIGH_ANOMALY')
    const after = await env.DB.prepare('SELECT * FROM claims WHERE id = ?').bind(claimId).first()
    expect(after).toEqual(before)
    // and reading it via the API changes nothing either
    await call(`/claims/${claimId}/risk-signals`, { as: assessorA })
    expect(await env.DB.prepare('SELECT * FROM claims WHERE id = ?').bind(claimId).first()).toEqual(before)
  })

  it('GET /risk-signals: same-tenant insurer 200; other tenant 404; customer 403; no token 401', async () => {
    const claimId = await verifiedClaim()
    await insertSignal(claimId, 0.5, 'NORMAL')
    const ok = await call(`/claims/${claimId}/risk-signals`, { as: assessorA })
    expect(ok.status).toBe(200)
    expect(await ok.json()).toMatchObject({ claimId, riskSignals: { quantumAnomaly: 0.5, interpretation: 'NORMAL' } })

    expect((await call(`/claims/${claimId}/risk-signals`, { as: assessorB })).status).toBe(404)
    expect((await call(`/claims/${claimId}/risk-signals`, { as: customerA })).status).toBe(403)
    expect((await call(`/claims/${claimId}/risk-signals`)).status).toBe(401)
    expect((await call('/claims/claim_does_not_exist/risk-signals', { as: assessorA })).status).toBe(404)
  })

  it('no route accepts a client-supplied score: bodies are ignored or rejected and the table is untouched', async () => {
    const claimId = await verifiedClaim()
    // /screen ignores any body; the score table must not gain a row from it
    const res = await call(`/claims/${claimId}/screen`, {
      method: 'POST',
      as: assessorA,
      json: { quantumAnomaly: 0.99, riskSignals: { quantumAnomaly: 0.99 } },
    })
    expect(res.status).toBe(200)
    expect(await env.DB.prepare('SELECT COUNT(*) AS n FROM screening_signals WHERE claim_id = ?').bind(claimId).first()).toEqual({ n: 0 })
    // the customer screening form has a strict schema
    const draft = await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001' } })
    const { claimId: draftId } = (await draft.json()) as { claimId: string }
    const patched = await call(`/claims/${draftId}/screening`, {
      method: 'PATCH',
      as: customerA,
      json: { causeOfLoss: 'x', incidentDate: '2026-01-10', quantumAnomaly: 0.01 },
    })
    expect(patched.status).toBe(400)
    // and there is no write route at all
    for (const method of ['POST', 'PUT', 'PATCH', 'DELETE']) {
      const r = await call(`/claims/${claimId}/risk-signals`, { method, as: assessorA, json: { quantumAnomaly: 0.01 } })
      expect([404, 405]).toContain(r.status)
    }
  })

  it('malformed rows are treated as absent (schema CHECKs reject them; the reader is defensive too)', async () => {
    const claimId = await verifiedClaim()
    await expect(
      env.DB.prepare(
        `INSERT INTO screening_signals (claim_id, model_version, classical_anomaly, quantum_anomaly, interpretation, execution, computed_at)
         VALUES (?, 'm', 0.1, 1.5, 'HIGH_ANOMALY', 'simulator', 'now')`
      )
        .bind(claimId)
        .run()
    ).rejects.toThrow()
    await expect(
      env.DB.prepare(
        `INSERT INTO screening_signals (claim_id, model_version, classical_anomaly, quantum_anomaly, interpretation, execution, computed_at)
         VALUES (?, 'm', 0.1, 0.5, 'FRAUD', 'simulator', 'now')`
      )
        .bind(claimId)
        .run()
    ).rejects.toThrow()
    await expect(
      env.DB.prepare(
        `INSERT INTO screening_signals (claim_id, model_version, classical_anomaly, quantum_anomaly, interpretation, execution, computed_at)
         VALUES (?, 'm', 0.1, 0.5, 'NORMAL', 'production-qpu', 'now')`
      )
        .bind(claimId)
        .run()
    ).rejects.toThrow()
    const res = await call(`/claims/${claimId}/risk-signals`, { as: assessorA })
    expect(await res.json()).toMatchObject({ riskSignals: null })
  })

  it('a signal cannot exist for a claim that does not exist (foreign key)', async () => {
    await expect(insertSignal('claim_ghost')).rejects.toThrow()
  })
})
