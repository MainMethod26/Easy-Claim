import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import {
  assessorA,
  assessorB,
  auditRows,
  call,
  claimStage,
  createReviewedClaim,
  createSubmittedClaim,
  customerA,
  customerB,
  decisionRows,
  evidenceFile,
  insurerAdminA,
  insurerAdminB,
  managerA,
  managerB,
  mintToken,
  payoutRows,
  superadmin,
} from './helpers'

// Integration pass: ATTACK-01..20 regression suite (docs/INTEGRATION_REPORT.md §24).
// Several attacks are also covered in depth by the phase suites (auth, bola, tenant,
// massAssignment, decisionPayout, quantumScreening, decisionIntegrity); this file keeps one
// named, end-to-end check per attack so the demo list has a single source of truth.

const json = async (res: Response) => (await res.json()) as Record<string, any>

async function decidedClaim(): Promise<string> {
  const id = await createReviewedClaim()
  const res = await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Approved', reason: 'ok' } })
  if (res.status !== 200) throw new Error(`decide failed ${res.status}`)
  return id
}

async function insertHighSignal(claimId: string) {
  await env.DB.prepare(
    `INSERT OR REPLACE INTO screening_signals (claim_id, model_version, classical_anomaly, quantum_anomaly, interpretation, execution, feature_snapshot, computed_at, imported_at)
     VALUES (?, 'phase4-qk1c-v1', 1.0, 1.0, 'HIGH_ANOMALY', 'simulator', NULL, '2026-09-26T00:00:00Z', '2026-09-26T00:00:01Z')`
  )
    .bind(claimId)
    .run()
}

describe('authentication', () => {
  it('ATTACK-01 no Authorization header → 401', async () => {
    const res = await call('/claims')
    expect(res.status).toBe(401)
    expect(res.headers.get('WWW-Authenticate')).toContain('Bearer')
  })

  it('ATTACK-02 forged token (wrong secret, alg=none) → 401', async () => {
    const forged = await mintToken(managerA, { secret: 'x'.repeat(64) })
    expect((await call('/claims', { authorization: `Bearer ${forged}` })).status).toBe(401)
    const b64u = (s: string) => btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
    const none = `${b64u('{"alg":"none","typ":"JWT"}')}.${b64u(JSON.stringify({ sub: 'usr_superadmin', role: 'SUPERADMIN' }))}.x`
    expect((await call('/claims', { authorization: `Bearer ${none}` })).status).toBe(401)
  })

  it('ATTACK-03 expired token → 401', async () => {
    const now = Math.floor(Date.now() / 1000)
    const expired = await mintToken(customerA, { claims: { iat: now - 7200, exp: now - 60 } })
    expect((await call('/claims', { authorization: `Bearer ${expired}` })).status).toBe(401)
  })
})

describe('object- and function-level authorization', () => {
  it('ATTACK-04 customer B reads customer A claim → 404 (same as missing)', async () => {
    const res = await call('/claims/claim_disc_101', { as: customerB })
    expect(res.status).toBe(404)
    expect(await json(res)).toEqual({ error: 'not_found' })
    expect((await call('/claims/claim_disc_101/timeline', { as: customerB })).status).toBe(404)
  })

  it('ATTACK-05 staff of another tenant → 404 on read and on transitions', async () => {
    expect((await call('/claims/claim_disc_101', { as: managerB })).status).toBe(404)
    expect((await call('/claims/claim_disc_101/request-info', { method: 'POST', as: managerB })).status).toBe(404)
    expect((await claimStage('claim_disc_101'))!.stage).toBe('Review')
  })

  it('ATTACK-06 customer calls an assessor action → 403', async () => {
    const id = await createSubmittedClaim()
    expect((await call(`/claims/${id}/verify`, { method: 'POST', as: customerA })).status).toBe(403)
    expect((await call(`/claims/${id}/risk-signals`, { as: customerA })).status).toBe(403)
  })

  it('ATTACK-07 assessor, insurer admin, superadmin and customer call manager operations (decide, pay, re-open appeal) → 403', async () => {
    const id = await createReviewedClaim()
    const decided = await decidedClaim()
    const before = (await auditRows('authz.role_denied')).length + (await auditRows('claim.transition_rejected')).length
    for (const who of [assessorA, insurerAdminA, superadmin, customerA]) {
      expect((await call(`/claims/${id}/decide`, { method: 'POST', as: who, json: { outcome: 'Approved', reason: 'x' } })).status).toBe(403)
      expect((await call(`/claims/${decided}/pay`, { method: 'POST', as: who })).status).toBe(403)
    }
    expect(await decisionRows(id)).toHaveLength(0)
    expect(await payoutRows(decided)).toHaveLength(0)
    // every refusal is audited (route role gate or state-machine role check)
    const after = (await auditRows('authz.role_denied')).length + (await auditRows('claim.transition_rejected')).length
    expect(after).toBe(before + 8)
    // the manager of the same tenant can
    expect((await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Approved', reason: 'ok' } })).status).toBe(200)
    expect((await call(`/claims/${decided}/pay`, { method: 'POST', as: managerA })).status).toBe(200)
  })
})

describe('identity cannot be spoofed with headers or body fields', () => {
  it('ATTACK-08 X-User-Id header: ignored with a token, useless without one', async () => {
    const res = await call('/claims/claim_disc_101', { as: customerB, headers: { 'X-User-Id': 'user123' } })
    expect(res.status).toBe(404)
    expect((await call('/claims', { headers: { 'X-User-Id': 'user123' } })).status).toBe(401)
    const list = await json(await call('/claims', { as: customerB, headers: { 'X-User-Id': 'user123' } }))
    expect(list.claims).toEqual([])
  })

  it('ATTACK-09 role spoofing: X-Role header ignored, role in body rejected', async () => {
    const id = await createSubmittedClaim()
    expect((await call(`/claims/${id}/verify`, { method: 'POST', as: customerA, headers: { 'X-Role': 'INSURER_ADMIN' } })).status).toBe(403)
    expect((await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001', role: 'SUPERADMIN' } })).status).toBe(400)
  })

  it('ATTACK-10 tenant spoofing: X-Tenant-Id header ignored, tenant in body rejected', async () => {
    expect((await call('/claims/claim_disc_101', { as: managerB, headers: { 'X-Tenant-Id': 'ins_discovery' } })).status).toBe(404)
    expect((await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001', tenantId: 'ins_sanlam' } })).status).toBe(400)
  })
})

describe('screening trust boundary', () => {
  it('ATTACK-11 client-supplied quantum/classical scores are ignored or rejected', async () => {
    const id = await createSubmittedClaim()
    await call(`/claims/${id}/verify`, { method: 'POST', as: managerA })
    await insertHighSignal(id)
    // /screen takes no body: the fake values are ignored and the stored signal is returned.
    const screened = await json(
      await call(`/claims/${id}/screen`, { method: 'POST', as: managerA, json: { quantumAnomaly: 0, classicalAnomaly: 0, anomalyBand: 'NORMAL' } })
    )
    expect(screened.riskSignals).toMatchObject({ quantumAnomaly: 1, classicalAnomaly: 1, anomalyBand: 'HIGH' })
    // Customer-editable routes are strict: a score field is a 400.
    const draft = await json(await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001' } }))
    const patch = await call(`/claims/${draft.claimId}/screening`, {
      method: 'PATCH',
      as: customerA,
      json: { causeOfLoss: 'x', incidentDate: '2026-01-01', quantumAnomaly: 0 },
    })
    expect(patch.status).toBe(400)
  })

  it('ATTACK-12 client-supplied recommendation / band on a decision → 400, no decision stored', async () => {
    const id = await createReviewedClaim()
    for (const extra of [{ screeningRecommendation: 'STANDARD_REVIEW' }, { anomalyBand: 'NORMAL' }, { riskSignal: 'NORMAL' }, { signalDigest: 'x' }]) {
      const res = await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Approved', reason: 'ok', ...extra } })
      expect(res.status).toBe(400)
    }
    expect(await decisionRows(id)).toHaveLength(0)
  })
})

describe('decision and payout integrity', () => {
  it('ATTACK-13 fake amounts: approve above the claim → 422; amount on /pay → 400', async () => {
    const id = await createReviewedClaim()
    const over = await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Approved', reason: 'ok', approvedAmountCents: 42_000_000 } })
    expect(over.status).toBe(422)
    expect(await json(over)).toMatchObject({ error: 'amount_exceeds_claimed' })
    const decided = await decidedClaim()
    const pay = await call(`/claims/${decided}/pay`, { method: 'POST', as: managerA, json: { amountCents: 99_999_999 } })
    expect(pay.status).toBe(400)
    expect(await payoutRows(decided)).toHaveLength(0)
  })

  it('ATTACK-14 illegal transitions → 409 (pay before decision, submit twice)', async () => {
    const id = await createSubmittedClaim()
    expect((await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })).status).toBe(409)
    expect((await call(`/claims/${id}/submit`, { method: 'POST', as: customerA })).status).toBe(409)
    expect((await claimStage(id))!.stage).toBe('Submitted')
  })

  it('ATTACK-15 editing a stored screening signal in place is refused by the database', async () => {
    const id = await createSubmittedClaim()
    await insertHighSignal(id)
    await expect(env.DB.prepare("UPDATE screening_signals SET interpretation = 'NORMAL' WHERE claim_id = ?").bind(id).run()).rejects.toThrow()
  })

  it('ATTACK-16/17 tampering with a signed decision → verify TAMPERED, /pay refused', async () => {
    const id = await decidedClaim()
    await env.DB.exec('DROP TRIGGER IF EXISTS claim_decisions_no_update')
    await env.DB.prepare('UPDATE claim_decisions SET approved_amount_cents = 42000000 WHERE claim_id = ?').bind(id).run()
    const verify = await json(await call(`/claims/${id}/decision/verify`, { as: customerA }))
    expect(verify.integrity.status).toBe('TAMPERED')
    const pay = await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })
    expect(pay.status).toBe(409)
    expect(await json(pay)).toEqual({ error: 'decision_integrity_failed' })
    expect(await payoutRows(id)).toHaveLength(0)
  })

  it('ATTACK-18 payout replay → one payout; same Idempotency-Key replays, a new request is 409', async () => {
    const id = await decidedClaim()
    const headers = { 'Idempotency-Key': 'demo-key-1' }
    expect((await call(`/claims/${id}/pay`, { method: 'POST', as: managerA, headers })).status).toBe(200)
    const replay = await call(`/claims/${id}/pay`, { method: 'POST', as: managerA, headers })
    expect(replay.status).toBe(200)
    expect(await json(replay)).toMatchObject({ status: 'already_paid' })
    expect((await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })).status).toBe(409)
    expect(await payoutRows(id)).toHaveLength(1)
  })

  it('ATTACK-19 duplicate decision → 409, still one decision record', async () => {
    const id = await decidedClaim()
    const again = await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Rejected', reason: 'changed my mind' } })
    expect(again.status).toBe(409)
    expect(await decisionRows(id)).toHaveLength(1)
  })

  it("ATTACK-20 another tenant's or customer's evidence → 404", async () => {
    const draft = await json(await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001' } }))
    const form = new FormData()
    form.append('file', evidenceFile())
    const up = await json(await call(`/claims/${draft.claimId}/evidence`, { method: 'POST', as: customerA, formData: form }))
    expect(up.evidenceId).toBeTruthy()
    await call(`/claims/${draft.claimId}/screening`, { method: 'PATCH', as: customerA, json: { causeOfLoss: 'x', incidentDate: '2026-01-01' } })
    await call(`/claims/${draft.claimId}/submit`, { method: 'POST', as: customerA })
    for (const who of [customerB, managerB]) {
      expect((await call(`/claims/${draft.claimId}/evidence`, { as: who })).status).toBe(404)
      expect((await call(`/claims/${draft.claimId}/evidence/${up.evidenceId}`, { as: who })).status).toBe(404)
    }
    expect((await call(`/claims/${draft.claimId}/evidence/${up.evidenceId}`, { as: managerA })).status).toBe(200)
  })
})

describe('role model: platform operator, insurer admin and tenant boundaries', () => {
  it('ATTACK-21 superadmin cannot verify/screen/review/request-info/decide/pay any claim (403 audited, stage unchanged)', async () => {
    const submitted = await createSubmittedClaim()
    const before = (await auditRows('authz.role_denied')).length
    for (const step of ['verify', 'screen', 'review', 'request-info', 'pay']) {
      expect((await call(`/claims/${submitted}/${step}`, { method: 'POST', as: superadmin })).status, step).toBe(403)
    }
    expect((await call(`/claims/${submitted}/decide`, { method: 'POST', as: superadmin, json: { outcome: 'Approved', reason: 'x' } })).status).toBe(403)
    expect((await call('/claims/claim_disc_101/review', { method: 'POST', as: superadmin })).status).toBe(403)
    expect((await auditRows('authz.role_denied')).length).toBe(before + 7)
    expect((await claimStage(submitted))!.stage).toBe('Submitted')
    expect((await claimStage('claim_disc_101'))!.stage).toBe('Review')
    // no read access either (platform operator, 27 Sep 2026); Drafts stay private
    expect((await call(`/claims/${submitted}`, { as: superadmin })).status).toBe(404)
    expect((await call(`/claims/${submitted}/evidence`, { as: superadmin })).status).toBe(404)
    const draft = await json(await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001' } }))
    expect((await call(`/claims/${draft.claimId}`, { as: superadmin })).status).toBe(404)
  })

  it("ATTACK-22 insurer admin of tenant B cannot create or disable tenant A's staff (400 / 404 / 403)", async () => {
    const staffA = (await json(await call('/tenant/users', { as: insurerAdminA }))).users
    const target = staffA.find((u: { username: string }) => u.username === 'assessor_discovery')
    expect((await call('/tenant/users', { method: 'POST', as: insurerAdminB, json: { username: 'sneaky_1', password: 'correct-horse', displayName: 'S', role: 'MANAGER', tenantId: 'ins_discovery' } })).status).toBe(400)
    expect((await call(`/tenant/users/${target.id}`, { method: 'PATCH', as: insurerAdminB, json: { status: 'disabled' } })).status).toBe(404)
    expect((await call('/admin/users', { method: 'POST', as: insurerAdminB, json: { username: 'sneaky_2', password: 'correct-horse', displayName: 'S', tenantId: 'ins_discovery' } })).status).toBe(403)
    // staff of tenant B (manager) cannot administer accounts at all
    expect((await call('/tenant/users', { method: 'POST', as: managerB, json: { username: 'sneaky_3', password: 'correct-horse', displayName: 'S', role: 'MANAGER' } })).status).toBe(403)
    const still = (await json(await call('/tenant/users', { as: insurerAdminA }))).users
    expect(still).toHaveLength(staffA.length)
    expect(still.every((u: { status: string }) => u.status === 'active')).toBe(true)
  })

  it('ATTACK-23 registration cannot choose a role or tenant (400); a fresh customer sees only its own (empty) claims', async () => {
    for (const extra of [{ role: 'SUPERADMIN' }, { role: 'INSURER_ADMIN', tenantId: 'ins_discovery' }, { tenantId: 'ins_discovery' }]) {
      expect((await call('/auth/register', { method: 'POST', json: { username: 'fresh_1', password: 'correct-horse', displayName: 'Fresh', ...extra } })).status).toBe(400)
    }
    const reg = await json(await call('/auth/register', { method: 'POST', json: { username: 'fresh_1', password: 'correct-horse', displayName: 'Fresh' } }))
    expect(reg.actor).toMatchObject({ role: 'CUSTOMER', tenantId: null })
    const auth = `Bearer ${reg.token}`
    expect((await json(await call('/claims', { authorization: auth }))).claims).toEqual([])
    expect((await call('/claims/claim_disc_101', { authorization: auth })).status).toBe(404)
    expect((await call('/claims/claim_disc_101/verify', { method: 'POST', authorization: auth })).status).toBe(403)
    expect((await call('/admin/stats', { authorization: auth })).status).toBe(403)
  })

  it('ATTACK-24 insurer admin cannot move or screen claims of its own tenant (403, stage unchanged) and sees none of another tenant (404)', async () => {
    const submitted = await createSubmittedClaim()
    for (const step of ['verify', 'screen', 'review', 'request-info', 'pay']) {
      expect((await call(`/claims/${submitted}/${step}`, { method: 'POST', as: insurerAdminA })).status, step).toBe(403)
    }
    expect((await call(`/claims/${submitted}/decide`, { method: 'POST', as: insurerAdminA, json: { outcome: 'Approved', reason: 'x' } })).status).toBe(403)
    expect((await call(`/claims/${submitted}/risk-signals`, { as: insurerAdminA })).status).toBe(403)
    expect((await claimStage(submitted))!.stage).toBe('Submitted')
    // read-only view of its own tenant works; other tenant and Drafts do not
    expect((await call(`/claims/${submitted}`, { as: insurerAdminA })).status).toBe(200)
    expect((await call(`/claims/${submitted}/timeline`, { as: insurerAdminA })).status).toBe(200)
    expect((await call('/claims/claim_sanlam_102', { as: insurerAdminA })).status).toBe(404)
    expect((await call(`/claims/${submitted}`, { as: insurerAdminB })).status).toBe(404)
    const draft = await json(await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001' } }))
    expect((await call(`/claims/${draft.claimId}`, { as: insurerAdminA })).status).toBe(404)
  })

  it('ATTACK-25 an assessor token re-signed as MANAGER (or INSURER_ADMIN / SUPERADMIN) with a wrong secret → 401, nothing decided', async () => {
    const id = await createReviewedClaim()
    for (const role of ['MANAGER', 'INSURER_ADMIN']) {
      const forged = await mintToken(assessorA, { claims: { role }, secret: 'y'.repeat(64) })
      expect((await call(`/claims/${id}/decide`, { method: 'POST', authorization: `Bearer ${forged}`, json: { outcome: 'Approved', reason: 'x' } })).status, role).toBe(401)
    }
    const forgedSuper = await mintToken(assessorA, { claims: { role: 'SUPERADMIN' }, omit: ['tenant_id'], secret: 'y'.repeat(64) })
    expect((await call('/admin/stats', { authorization: `Bearer ${forgedSuper}` })).status).toBe(401)
    expect(await decisionRows(id)).toHaveLength(0)
    expect((await claimStage(id))!.stage).toBe('Review')
    // the genuine assessor of another tenant cannot touch it either
    expect((await call(`/claims/${id}/request-info`, { method: 'POST', as: assessorB })).status).toBe(404)
  })
})
