import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import { readRiskSignals } from '../src/screening/quantumSignal'
import {
  assessorA,
  assessorB,
  auditRows,
  call,
  claimStage,
  createSubmittedClaim,
  customerA,
  customerB,
  decisionRows,
  managerA,
  payoutRows,
} from './helpers'

// Phase 4 completion: QUANTUM-06..12 and attacks 1-5 of the completion brief.
// QUANTUM-01..05 (determinism, classical and quantum runs, numeric bounds, missing/invalid features)
// are covered in quantum/tests (pytest). The signal is advisory: these tests prove it inherits every
// gate, is auditable and tamper-evident, and can never move a claim on its own.

const MODEL = 'phase4-qk1c-v1'

async function insertSignal(claimId: string, quantum = 0.99, interpretation = 'HIGH_ANOMALY', classical = 0.95) {
  await env.DB.prepare(
    `INSERT OR REPLACE INTO screening_signals (claim_id, model_version, classical_anomaly, quantum_anomaly, interpretation, execution, feature_snapshot, computed_at, imported_at)
     VALUES (?, ?, ?, ?, ?, 'simulator', '{"days_to_report":{"raw":300,"scaled":0.99}}', '2026-09-26T00:00:00Z', '2026-09-26T00:00:01Z')`
  )
    .bind(claimId, MODEL, classical, quantum, interpretation)
    .run()
}

async function verifiedClaim(): Promise<string> {
  const claimId = await createSubmittedClaim()
  const res = await call(`/claims/${claimId}/verify`, { method: 'POST', as: assessorA })
  if (res.status !== 200) throw new Error(`verify failed: ${res.status}`)
  return claimId
}

interface Signal {
  anomalyBand: string
  screeningRecommendation: string
  signalDigest: string
  versions: Record<string, string>
  advisory: boolean
  explanation: string
}

describe('signal contract', () => {
  it('HIGH anomaly: band HIGH, REVIEW_REQUIRED, versioned, digest, advisory, never the word "fraud" as a verdict', async () => {
    const id = await verifiedClaim()
    await insertSignal(id)
    const res = await call(`/claims/${id}/screen`, { method: 'POST', as: assessorA })
    const { riskSignals } = (await res.json()) as { riskSignals: Signal }
    expect(riskSignals).toMatchObject({
      interpretation: 'HIGH_ANOMALY',
      anomalyBand: 'HIGH',
      screeningRecommendation: 'REVIEW_REQUIRED',
      advisory: true,
      versions: { model: MODEL, features: 'claim-features-v1', kernel: 'qk-fidelity-zz-r2-v1', screening: 'phase4-screening-v1' },
    })
    expect(riskSignals.signalDigest).toMatch(/^[0-9a-f]{64}$/)
    expect(riskSignals.explanation).toContain('not a fraud finding')
    expect(JSON.stringify(riskSignals)).not.toMatch(/"(fraud|FRAUD)"/)
  })

  it('NORMAL → STANDARD_REVIEW; UNUSUAL → ELEVATED / REVIEW_REQUIRED; unknown model version is reported, not guessed', async () => {
    const a = await verifiedClaim()
    await insertSignal(a, 0.1, 'NORMAL', 0.2)
    const na = (await (await call(`/claims/${a}/risk-signals`, { as: assessorA })).json()) as { riskSignals: Signal }
    expect(na.riskSignals).toMatchObject({ anomalyBand: 'NORMAL', screeningRecommendation: 'STANDARD_REVIEW' })

    const b = await verifiedClaim()
    await env.DB.prepare(
      `INSERT INTO screening_signals (claim_id, model_version, classical_anomaly, quantum_anomaly, interpretation, execution, computed_at)
       VALUES (?, 'future-model', 0.8, 0.85, 'UNUSUAL', 'simulator', '2026-09-26T00:00:00Z')`
    ).bind(b).run()
    const nb = (await (await call(`/claims/${b}/risk-signals`, { as: assessorA })).json()) as { riskSignals: Signal }
    expect(nb.riskSignals).toMatchObject({ anomalyBand: 'ELEVATED', screeningRecommendation: 'REVIEW_REQUIRED' })
    expect(nb.riskSignals.versions).toMatchObject({ model: 'future-model', features: 'unknown', kernel: 'unknown' })
  })

  it('reader is defensive: malformed rows returned by the database are treated as absent', async () => {
    const stub = (row: unknown) =>
      ({ prepare: () => ({ bind: () => ({ first: async () => row }) }) }) as unknown as D1Database
    const base = { claim_id: 'c', model_version: MODEL, classical_anomaly: 0.1, quantum_anomaly: 0.2, interpretation: 'NORMAL', execution: 'simulator', feature_snapshot: null, computed_at: 't' }
    expect(await readRiskSignals(stub(base), 'c')).not.toBeNull()
    for (const bad of [
      { interpretation: 'FRAUD' },
      { execution: 'production-qpu' },
      { quantum_anomaly: 1.5 },
      { classical_anomaly: -0.1 },
      { quantum_anomaly: Number.NaN },
      { classical_anomaly: '0.5' },
    ]) {
      expect(await readRiskSignals(stub({ ...base, ...bad }), 'c')).toBeNull()
    }
    expect(await readRiskSignals(stub(null), 'c')).toBeNull()
  })
})

describe('QUANTUM-06/07: screening inherits ownership and tenant isolation', () => {
  it('customer of the claim → 403 on screening routes; other customer → 403; other tenant → 404; no token → 401', async () => {
    const id = await verifiedClaim()
    await insertSignal(id)
    expect((await call(`/claims/${id}/screen`, { method: 'POST', as: customerA })).status).toBe(403)
    expect((await call(`/claims/${id}/screen`, { method: 'POST', as: customerB })).status).toBe(403)
    expect((await call(`/claims/${id}/risk-signals`, { as: customerB })).status).toBe(403)
    expect((await call(`/claims/${id}/screen`, { method: 'POST', as: assessorB })).status).toBe(404)
    expect((await call(`/claims/${id}/risk-signals`, { as: assessorB })).status).toBe(404)
    expect((await call(`/claims/${id}/risk-signals`)).status).toBe(401)
    expect(await claimStage(id)).toMatchObject({ stage: 'Verified' })
    // the cross-tenant attempt is audited with the actor's tenant, never the claim's
    const denied = await auditRows('authz.claim_access_denied', id)
    expect(denied.some((r) => r.actor_tenant_id === 'ins_sanlam')).toBe(true)
  })
})

describe('QUANTUM-08 / Attack 1: a client cannot supply a trusted score', () => {
  it.each([{ quantumScore: 0 }, { quantumScore: 'LOW' }, { riskSignals: { anomalyBand: 'NORMAL' } }, { quantumAnomaly: 0, classicalAnomaly: 0 }])(
    'body %o is ignored on /screen and rejected on /decide; stored signal and response unchanged',
    async (fake) => {
      const id = await verifiedClaim()
      await insertSignal(id)
      const screen = await call(`/claims/${id}/screen`, { method: 'POST', as: assessorA, json: fake })
      expect(screen.status).toBe(200)
      expect(((await screen.json()) as { riskSignals: Signal }).riskSignals).toMatchObject({ anomalyBand: 'HIGH' })
      const row = await env.DB.prepare('SELECT quantum_anomaly, interpretation FROM screening_signals WHERE claim_id = ?').bind(id).first()
      expect(row).toEqual({ quantum_anomaly: 0.99, interpretation: 'HIGH_ANOMALY' })

      await call(`/claims/${id}/review`, { method: 'POST', as: assessorA })
      const decide = await call(`/claims/${id}/decide`, {
        method: 'POST',
        as: managerA,
        json: { outcome: 'Approved', reason: 'x', ...fake },
      })
      expect(decide.status).toBe(400)
      expect(await claimStage(id)).toMatchObject({ stage: 'Review' })
    }
  )

  it('no write route exists for signals', async () => {
    const id = await verifiedClaim()
    for (const method of ['POST', 'PUT', 'PATCH', 'DELETE']) {
      const res = await call(`/claims/${id}/risk-signals`, { method, as: managerA, json: { quantumAnomaly: 0 } })
      expect([404, 405]).toContain(res.status)
    }
    expect(await env.DB.prepare('SELECT count(*) AS n FROM screening_signals WHERE claim_id = ?').bind(id).first()).toEqual({ n: 0 })
  })
})

describe('QUANTUM-09/12 / Attack 5: the signal never moves a claim; humans do', () => {
  it('HIGH anomaly: /screen only reaches Screening; nothing reaches Decision/Paid without the human routes; then the normal human path works', async () => {
    const id = await verifiedClaim()
    await insertSignal(id)
    const screen = await call(`/claims/${id}/screen`, { method: 'POST', as: assessorA })
    expect(((await screen.json()) as { to: string }).to).toBe('Screening')
    expect(await claimStage(id)).toMatchObject({ stage: 'Screening', status: 'Pending' })

    // no shortcut from a signal to an outcome
    expect((await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })).status).toBe(409)
    expect((await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Rejected', reason: 'high anomaly' } })).status).toBe(409)
    expect(await decisionRows(id)).toHaveLength(0)

    // the human workflow continues unchanged
    expect((await call(`/claims/${id}/review`, { method: 'POST', as: assessorA })).status).toBe(200)
    expect((await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Approved', reason: 'Reviewed; anomaly explained by late reporting' } })).status).toBe(200)
    expect((await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })).status).toBe(200)
    expect(await claimStage(id)).toMatchObject({ stage: 'Paid', status: 'Approved' })
    expect(await payoutRows(id)).toHaveLength(1)
  })

  it('NORMAL signal and no signal behave identically in the workflow', async () => {
    for (const setup of [async (id: string) => insertSignal(id, 0.1, 'NORMAL', 0.2), async () => undefined]) {
      const id = await verifiedClaim()
      await setup(id)
      for (const step of ['screen', 'review']) expect((await call(`/claims/${id}/${step}`, { method: 'POST', as: assessorA })).status).toBe(200)
      expect((await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Rejected', reason: 'Outside cover' } })).status).toBe(200)
      expect(await claimStage(id)).toMatchObject({ stage: 'Decision', status: 'Rejected' })
    }
  })
})

describe('QUANTUM-10 / Attack 4: screening is auditable and tampering is detectable', () => {
  it('attach and read are audited with the digest; the decision records the signal the manager had', async () => {
    const id = await verifiedClaim()
    await insertSignal(id)
    const screen = (await (await call(`/claims/${id}/screen`, { method: 'POST', as: assessorA })).json()) as { riskSignals: Signal }
    const digest = screen.riskSignals.signalDigest

    const attached = await auditRows('screening.signal_attached', id)
    expect(attached).toHaveLength(1)
    expect(attached[0]).toMatchObject({ actor_id: 'assessor_a1', actor_tenant_id: 'ins_discovery', outcome: 'success' })
    expect(JSON.parse(attached[0].details as string)).toMatchObject({ band: 'HIGH', recommendation: 'REVIEW_REQUIRED', model: MODEL, digest })
    expect(attached[0].details as string).not.toContain('days_to_report') // no feature values in audit

    await call(`/claims/${id}/risk-signals`, { as: managerA })
    const read = await auditRows('screening.signal_read', id)
    expect(JSON.parse(read[0].details as string)).toMatchObject({ digest })

    await call(`/claims/${id}/review`, { method: 'POST', as: assessorA })
    await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Approved', reason: 'ok' } })
    const decision = (await decisionRows(id))[0]
    expect(JSON.parse(decision.risk_signal as string)).toMatchObject({ band: 'HIGH', quantum: 0.99, digest })
  })

  it('no signal → audit records band null and the decision stores risk_signal NULL', async () => {
    const id = await verifiedClaim()
    await call(`/claims/${id}/screen`, { method: 'POST', as: assessorA })
    expect(JSON.parse((await auditRows('screening.signal_attached', id))[0].details as string)).toEqual({ band: null })
    await call(`/claims/${id}/review`, { method: 'POST', as: assessorA })
    await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Rejected', reason: 'x' } })
    expect((await decisionRows(id))[0].risk_signal).toBeNull()
  })

  it('in-place edits are refused; a re-import is visible as a different digest from the audited one', async () => {
    const id = await verifiedClaim()
    await insertSignal(id)
    const before = ((await (await call(`/claims/${id}/risk-signals`, { as: assessorA })).json()) as { riskSignals: Signal }).riskSignals.signalDigest

    await expect(env.DB.prepare('UPDATE screening_signals SET quantum_anomaly = 0.01 WHERE claim_id = ?').bind(id).run()).rejects.toThrow(/never edited in place/)

    // a replace (how a new model run is published) goes through, but it no longer matches the audit trail
    await insertSignal(id, 0.01, 'NORMAL', 0.01)
    const after = ((await (await call(`/claims/${id}/risk-signals`, { as: assessorA })).json()) as { riskSignals: Signal }).riskSignals.signalDigest
    expect(after).not.toBe(before)
    const digests = (await auditRows('screening.signal_read', id)).map((r) => JSON.parse(r.details as string).digest)
    expect(digests).toEqual([before, after])
  })
})
