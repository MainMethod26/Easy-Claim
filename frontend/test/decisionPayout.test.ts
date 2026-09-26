import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import { sha256Hex } from '../src/security/ledger'
import {
  DEMO_PAYOUT,
  VALID_PDF_BYTES,
  assessorA,
  auditRows,
  call,
  claimStage,
  createReadyDraft,
  createReviewedClaim,
  createSubmittedClaim,
  customerA,
  customerB,
  decisionRows,
  evidenceFile,
  managerA,
  managerB,
  payoutRows,
  setPayoutDetails,
} from './helpers'

// Phase 3: decision + payout security. The legitimate demo payout is R4 200 (420 000 cents).
const APPROVE = { outcome: 'Approved', reason: 'Documents verified, within cover' } as const
const REJECT = { outcome: 'Rejected', reason: 'Incident outside cover period' } as const

async function approvedClaim(): Promise<{ id: string; decisionId: string }> {
  const id = await createReviewedClaim()
  const res = await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: APPROVE })
  if (res.status !== 200) throw new Error(`decide failed: ${res.status} ${await res.text()}`)
  const { decisionId } = (await res.json()) as { decisionId: string }
  return { id, decisionId }
}

describe('decision authorization', () => {
  it('P3-01 customer cannot approve a claim (403, role denial audited, no decision row)', async () => {
    const id = await createReviewedClaim()
    const res = await call(`/claims/${id}/decide`, { method: 'POST', as: customerA, json: APPROVE })
    expect(res.status).toBe(403)
    expect(await res.json()).toEqual({ error: 'forbidden' })
    expect(await claimStage(id)).toMatchObject({ stage: 'Review' })
    expect(await decisionRows(id)).toHaveLength(0)
    expect((await auditRows('authz.role_denied')).length).toBeGreaterThan(0)
  })

  it('P3-02 assessor (unauthorized insurer role) cannot decide (403, transition_rejected audited)', async () => {
    const id = await createReviewedClaim()
    const res = await call(`/claims/${id}/decide`, { method: 'POST', as: assessorA, json: APPROVE })
    expect(res.status).toBe(403)
    expect(await claimStage(id)).toMatchObject({ stage: 'Review', status: 'Pending' })
    expect(await decisionRows(id)).toHaveLength(0)
    const rejected = await auditRows('claim.transition_rejected', id)
    expect(JSON.parse(rejected[0].details as string)).toMatchObject({ to: 'Decision', reason: 'role_not_permitted' })
  })

  it('P3-07a cross-tenant manager cannot decide (404, stage unchanged)', async () => {
    const id = await createReviewedClaim()
    expect((await call(`/claims/${id}/decide`, { method: 'POST', as: managerB, json: APPROVE })).status).toBe(404)
    expect(await claimStage(id)).toMatchObject({ stage: 'Review' })
    expect(await decisionRows(id)).toHaveLength(0)
  })

  it('P3-10 valid authorized decision succeeds and is recorded (who / what / when / claim / why / inputs)', async () => {
    const id = await createReviewedClaim()
    const res = await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: APPROVE })
    expect(res.status).toBe(200)
    const body = (await res.json()) as Record<string, unknown>
    expect(body).toMatchObject({ from: 'Review', to: 'Decision', outcome: 'Approved', approvedAmountCents: 420_000 })
    expect(await claimStage(id)).toMatchObject({ stage: 'Decision', status: 'Approved' })

    const rows = await decisionRows(id)
    expect(rows).toHaveLength(1)
    expect(rows[0]).toMatchObject({
      id: body.decisionId,
      claim_id: id,
      tenant_id: 'ins_discovery',
      outcome: 'Approved',
      reason: APPROVE.reason,
      previous_stage: 'Review',
      claimed_amount_cents: 420_000,
      approved_amount_cents: 420_000,
      actor_id: 'manager_a1',
      actor_role: 'MANAGER',
      rules_version: 'phase3-manual-v1',
    })
    expect(rows[0].decided_at).toMatch(/^\d{4}-\d{2}-\d{2}T/)
    expect(rows[0].destination_hash).toMatch(/^[0-9a-f]{64}$/)
    expect(rows[0].request_id).toMatch(/^[0-9a-f-]{36}$/)

    // the customer sees the outcome and rationale through the existing endpoint
    const view = (await (await call(`/claims/${id}/decision`, { as: customerA })).json()) as Record<string, unknown>
    expect(view).toMatchObject({ decision: 'Approved', record: { reason: APPROVE.reason, approvedAmountCents: 420_000, decidedByRole: 'MANAGER' } })
  })

  it('partial approval: approved amount below the claimed amount is recorded; rejection carries no amount', async () => {
    const id = await createReviewedClaim()
    const res = await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { ...APPROVE, approvedAmountCents: 300_000 } })
    expect(res.status).toBe(200)
    expect((await decisionRows(id))[0]).toMatchObject({ approved_amount_cents: 300_000, claimed_amount_cents: 420_000 })

    const id2 = await createReviewedClaim()
    expect((await call(`/claims/${id2}/decide`, { method: 'POST', as: managerA, json: { ...REJECT, approvedAmountCents: 1 } })).status).toBe(422)
    expect((await call(`/claims/${id2}/decide`, { method: 'POST', as: managerA, json: REJECT })).status).toBe(200)
    expect((await decisionRows(id2))[0]).toMatchObject({ outcome: 'Rejected', approved_amount_cents: null })
  })

  it('decision requires a reason and rejects any other field', async () => {
    const id = await createReviewedClaim()
    expect((await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Approved' } })).status).toBe(400)
    expect((await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { ...APPROVE, actorId: 'someone_else' } })).status).toBe(400)
    expect((await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { ...APPROVE, state: 'Paid' } })).status).toBe(400)
    expect(await claimStage(id)).toMatchObject({ stage: 'Review' })
  })

  it('approval is refused when the customer never supplied payout details', async () => {
    // build a reviewed claim without payout details
    const res = await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001' } })
    const { claimId } = (await res.json()) as { claimId: string }
    await call(`/claims/${claimId}/screening`, { method: 'PATCH', as: customerA, json: { causeOfLoss: 'x', incidentDate: '2026-01-10' } })
    await call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA })
    for (const step of ['verify', 'screen', 'review']) await call(`/claims/${claimId}/${step}`, { method: 'POST', as: assessorA })
    const decide = await call(`/claims/${claimId}/decide`, { method: 'POST', as: managerA, json: APPROVE })
    expect(decide.status).toBe(422)
    expect(await decide.json()).toEqual({ error: 'payout_details_missing' })
    expect((await auditRows('claim.decision_rejected', claimId))[0]).toBeDefined()
    // a rejection is still possible
    expect((await call(`/claims/${claimId}/decide`, { method: 'POST', as: managerA, json: REJECT })).status).toBe(200)
  })
})

describe('state-machine protection', () => {
  it('P3-03 clients cannot submit arbitrary state values', async () => {
    const id = await createSubmittedClaim()
    // customer: unknown/privileged fields on the only customer write route
    const patch = await call(`/claims/${id}/screening`, { method: 'PATCH', as: customerA, json: { causeOfLoss: 'x', incidentDate: '2026-01-10', state: 'Paid' } })
    expect(patch.status).toBe(400)
    const patch2 = await call(`/claims/${id}/payout-details`, { method: 'PUT', as: customerA, json: { ...DEMO_PAYOUT, stage: 'Paid' } })
    expect(patch2.status).toBe(400)
    // manager: state field on decide
    expect((await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { ...APPROVE, state: 'Paid' } })).status).toBe(400)
    // no generic transition route exists
    expect((await call(`/claims/${id}/transition`, { method: 'POST', as: managerA, json: { to: 'Paid' } })).status).toBe(404)
    expect(await claimStage(id)).toMatchObject({ stage: 'Submitted' })
  })

  it('P3-04 Submitted → Paid is refused (409 illegal_transition, audited), even for a manager', async () => {
    const id = await createSubmittedClaim()
    const res = await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })
    expect(res.status).toBe(409)
    expect(await res.json()).toEqual({ error: 'illegal_transition' })
    expect(await claimStage(id)).toMatchObject({ stage: 'Submitted' })
    expect(await payoutRows(id)).toHaveLength(0)
    expect(JSON.parse((await auditRows('claim.transition_rejected', id))[0].details as string)).toMatchObject({ from: 'Submitted', to: 'Paid' })
  })

  it('Review → Paid (skipping the decision) is refused', async () => {
    const id = await createReviewedClaim()
    expect((await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })).status).toBe(409)
    expect(await payoutRows(id)).toHaveLength(0)
  })
})

describe('payout protection', () => {
  it('P3-05 payout amount cannot be manipulated: R420 000 against a R4 200 claim is blocked at decision and at payout', async () => {
    const id = await createReviewedClaim()
    // at decision time: approving more than was claimed
    const over = await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { ...APPROVE, approvedAmountCents: 42_000_000 } })
    expect(over.status).toBe(422)
    expect(await over.json()).toEqual({ error: 'amount_exceeds_claimed' })
    expect(await decisionRows(id)).toHaveLength(0)

    // legitimate decision, then a payout request that carries an amount
    expect((await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: APPROVE })).status).toBe(200)
    const forged = await call(`/claims/${id}/pay`, { method: 'POST', as: managerA, json: { amount: 42_000_000 } })
    expect(forged.status).toBe(400)
    expect(await forged.json()).toEqual({ error: 'client_supplied_fields' })
    expect(await claimStage(id)).toMatchObject({ stage: 'Decision' })
    expect(await payoutRows(id)).toHaveLength(0)
    const blockedRows = await auditRows('payout.blocked', id)
    expect(JSON.parse(blockedRows[0].details as string)).toMatchObject({ reason: 'client_supplied_fields', fields: 'amount' })

    // the real payout pays exactly the recorded amount
    const pay = await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })
    expect(pay.status).toBe(200)
    expect(await pay.json()).toMatchObject({ status: 'paid', simulated: true, amountCents: 420_000 })
    expect((await payoutRows(id))[0]).toMatchObject({ amount_cents: 420_000, status: 'simulated' })
  })

  it('P3-06 payout destination cannot be changed after submission; a tampered destination blocks the payout', async () => {
    const { id, decisionId } = await approvedClaim()

    // the owner tries to redirect the payout after approval
    const change = await setPayoutDetails(id, { accountNumber: '99990000111122' })
    expect(change.status).toBe(409)
    expect(await change.json()).toMatchObject({ error: 'payout_details_locked' })
    expect(JSON.parse((await auditRows('payout.destination_change_blocked', id))[0].details as string)).toMatchObject({ reason: 'locked_after_submission' })

    // another customer cannot touch it at all
    expect((await setPayoutDetails(id)).status).toBe(409)
    expect((await call(`/claims/${id}/payout-details`, { method: 'PUT', as: customerB, json: DEMO_PAYOUT })).status).toBe(404)

    // even a direct database change of the destination is caught by the decision snapshot
    await env.DB.prepare("UPDATE claims SET payout_destination_hash = 'deadbeef', payout_account_last4 = '1122' WHERE id = ?").bind(id).run()
    const pay = await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })
    expect(pay.status).toBe(409)
    expect(await pay.json()).toEqual({ error: 'destination_mismatch' })
    expect(await claimStage(id)).toMatchObject({ stage: 'Decision' })
    expect(await payoutRows(id)).toHaveLength(0)
    const blocked = (await auditRows('payout.blocked', id)).map((r) => JSON.parse(r.details as string))
    expect(blocked).toContainEqual(expect.objectContaining({ reason: 'destination_mismatch', decisionId }))
  })

  it('P3-07b cross-tenant manager cannot pay (404, no payout)', async () => {
    const { id } = await approvedClaim()
    expect((await call(`/claims/${id}/pay`, { method: 'POST', as: managerB })).status).toBe(404)
    expect(await claimStage(id)).toMatchObject({ stage: 'Decision' })
    expect(await payoutRows(id)).toHaveLength(0)
  })

  it('assessor cannot pay (403) and a customer cannot pay (403)', async () => {
    const { id } = await approvedClaim()
    expect((await call(`/claims/${id}/pay`, { method: 'POST', as: assessorA })).status).toBe(403)
    expect((await call(`/claims/${id}/pay`, { method: 'POST', as: customerA })).status).toBe(403)
    expect(await payoutRows(id)).toHaveLength(0)
  })

  it('P3-08 duplicate payout: repeated request is refused; identical Idempotency-Key replays the same payout', async () => {
    const { id } = await approvedClaim()
    const first = await call(`/claims/${id}/pay`, { method: 'POST', as: managerA, headers: { 'Idempotency-Key': 'pay-req-1' } })
    expect(first.status).toBe(200)
    const { payoutId } = (await first.json()) as { payoutId: string }

    const again = await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })
    expect(again.status).toBe(409)
    expect(await again.json()).toEqual({ error: 'already_paid' })
    const otherKey = await call(`/claims/${id}/pay`, { method: 'POST', as: managerA, headers: { 'Idempotency-Key': 'pay-req-2' } })
    expect(otherKey.status).toBe(409)
    const sameKey = await call(`/claims/${id}/pay`, { method: 'POST', as: managerA, headers: { 'Idempotency-Key': 'pay-req-1' } })
    expect(sameKey.status).toBe(200)
    expect(await sameKey.json()).toMatchObject({ status: 'already_paid', payoutId })

    expect(await payoutRows(id)).toHaveLength(1)
    expect(await auditRows('claim.stage_changed', id)).toHaveLength(6) // Submitted…Paid, once each
    expect(await auditRows('payout.replayed_idempotent')).toHaveLength(1)
  })

  it('concurrent payout requests produce exactly one payout row', async () => {
    const { id } = await approvedClaim()
    const results = await Promise.all([1, 2, 3].map(() => call(`/claims/${id}/pay`, { method: 'POST', as: managerA })))
    expect(results.map((r) => r.status).sort()).toEqual([200, 409, 409])
    expect(await payoutRows(id)).toHaveLength(1)
    expect(await auditRows('claim.stage_changed', id)).toHaveLength(6)
  })

  it('P3-11 valid payout after a legitimate decision succeeds (simulated) and is bound to the decision', async () => {
    const { id, decisionId } = await approvedClaim()
    const res = await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })
    expect(res.status).toBe(200)
    expect(await res.json()).toMatchObject({
      status: 'paid',
      simulated: true,
      decisionId,
      amountCents: 420_000,
      destination: { bankName: 'Demo Bank', accountLast4: '7890' },
    })
    expect(await claimStage(id)).toMatchObject({ stage: 'Paid', status: 'Approved' })
    expect((await payoutRows(id))[0]).toMatchObject({ decision_id: decisionId, amount_cents: 420_000, destination_last4: '7890', initiated_by: 'manager_a1', initiated_role: 'MANAGER', tenant_id: 'ins_discovery' })

    const view = (await (await call(`/claims/${id}/payout`, { as: customerA })).json()) as Record<string, unknown>
    expect(view).toMatchObject({ stage: 'Paid', claimedAmountCents: 420_000, payout: { amountCents: 420_000, status: 'simulated' } })
  })

  it('a rejected decision cannot be paid and a pre-Phase-3 approval without a record cannot be paid', async () => {
    const id = await createReviewedClaim()
    await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: REJECT })
    expect(await (await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })).json()).toEqual({ error: 'not_approved' })
    // seed claim_sanlam_102 is Decision/Approved with no decision record
    const legacy = await call('/claims/claim_sanlam_102/pay', { method: 'POST', as: managerB })
    expect(legacy.status).toBe(409)
    expect(await legacy.json()).toEqual({ error: 'decision_record_missing' })
  })

  it('the full account number is never stored or returned', async () => {
    const { id } = await approvedClaim()
    await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })
    const dumps = await Promise.all(
      ['claims', 'claim_decisions', 'payouts', 'audit_events'].map(async (t) => JSON.stringify((await env.DB.prepare(`SELECT * FROM ${t}`).all()).results))
    )
    for (const d of dumps) expect(d).not.toContain(DEMO_PAYOUT.accountNumber)
    const view = await (await call(`/claims/${id}/payout`, { as: managerA })).text()
    expect(view).not.toContain(DEMO_PAYOUT.accountNumber)
    expect(view).toContain('7890')
  })
})

describe('decision is bound to the evidence set (Phase 2 → Phase 3)', () => {
  const pdf = (bytes: Uint8Array) => {
    const form = new FormData()
    form.append('file', evidenceFile(bytes))
    return form
  }

  it('records the SHA-256 over the claim\'s evidence hashes at decision time, re-computable from the evidence table', async () => {
    const id = await createReadyDraft()
    const bytesA = new Uint8Array([...VALID_PDF_BYTES, 1, 2, 3])
    const bytesB = new Uint8Array([...VALID_PDF_BYTES, 9, 9, 9])
    for (const b of [bytesA, bytesB]) {
      const up = await call(`/claims/${id}/evidence`, { method: 'POST', as: customerA, formData: pdf(b) })
      expect(up.status).toBe(201)
    }
    await call(`/claims/${id}/submit`, { method: 'POST', as: customerA })
    for (const step of ['verify', 'screen', 'review']) await call(`/claims/${id}/${step}`, { method: 'POST', as: assessorA })

    const res = await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: APPROVE })
    expect(res.status).toBe(200)
    const body = (await res.json()) as { evidenceCount: number; evidenceDigest: string }
    expect(body.evidenceCount).toBe(2)

    const hashes = (await env.DB.prepare('SELECT sha256 FROM evidence WHERE claim_id = ? ORDER BY sha256').bind(id).all<{ sha256: string }>()).results.map((r) => r.sha256)
    const expected = await sha256Hex(hashes.join('\n'))
    expect(body.evidenceDigest).toBe(expected)
    expect((await decisionRows(id))[0]).toMatchObject({ evidence_digest: expected })

    const view = (await (await call(`/claims/${id}/decision`, { as: customerA })).json()) as { record: { evidenceDigest: string } }
    expect(view.record.evidenceDigest).toBe(expected)
  })

  it('a claim decided without evidence records a null digest and count 0', async () => {
    const id = await createReviewedClaim()
    const res = await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: APPROVE })
    expect(await res.json()).toMatchObject({ evidenceCount: 0, evidenceDigest: null })
    expect((await decisionRows(id))[0]).toMatchObject({ evidence_digest: null })
  })

  it('evidence cannot be added or changed after submission, so the digest stays meaningful', async () => {
    const id = await createSubmittedClaim()
    const late = await call(`/claims/${id}/evidence`, { method: 'POST', as: customerA, formData: pdf(VALID_PDF_BYTES) })
    expect(late.status).toBe(409)
  })
})

describe('decision history integrity', () => {
  it('P3-09 decision, payout and audit history cannot be rewritten or deleted, and no route exposes writes to them', async () => {
    const { id } = await approvedClaim()
    await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })

    await expect(env.DB.prepare("UPDATE claim_decisions SET outcome = 'Rejected' WHERE claim_id = ?").bind(id).run()).rejects.toThrow(/append-only/)
    await expect(env.DB.prepare('DELETE FROM claim_decisions WHERE claim_id = ?').bind(id).run()).rejects.toThrow(/append-only/)
    await expect(env.DB.prepare('UPDATE payouts SET amount_cents = 1 WHERE claim_id = ?').bind(id).run()).rejects.toThrow(/append-only/)
    await expect(env.DB.prepare('DELETE FROM payouts WHERE claim_id = ?').bind(id).run()).rejects.toThrow(/append-only/)
    await expect(env.DB.prepare("UPDATE audit_events SET outcome = 'success' WHERE resource_id = ?").bind(id).run()).rejects.toThrow(/append-only/)

    for (const [method, path] of [
      ['DELETE', `/claims/${id}/decision`],
      ['PATCH', `/claims/${id}/decision`],
      ['DELETE', `/claims/${id}/payout`],
      ['POST', '/activities/audit-trail'],
      ['DELETE', '/activities/audit-trail'],
    ] as const) {
      expect((await call(path, { method, as: managerA, json: {} })).status).toBe(404)
    }
    expect(await decisionRows(id)).toHaveLength(1)
    expect(await payoutRows(id)).toHaveLength(1)
  })

  it('P3-12 decision and payout leave a reconstructable audit trail (who, what, when, claim, result)', async () => {
    const { id, decisionId } = await approvedClaim()
    await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })

    const decided = (await auditRows('claim.stage_changed', id)).find((r) => JSON.parse(r.details as string).to === 'Decision')!
    expect(decided).toMatchObject({ actor_id: 'manager_a1', actor_role: 'MANAGER', actor_tenant_id: 'ins_discovery', outcome: 'success' })
    expect(JSON.parse(decided.details as string)).toMatchObject({ from: 'Review', to: 'Decision', outcome: 'Approved', decisionId, approvedAmountCents: 420_000 })
    expect(decided.occurred_at).toMatch(/^\d{4}/)
    expect(decided.request_id).toMatch(/^[0-9a-f-]{36}$/)

    const recorded = await auditRows('claim.decision_recorded', decisionId)
    expect(recorded).toHaveLength(1)

    const paid = (await auditRows('claim.stage_changed', id)).find((r) => JSON.parse(r.details as string).to === 'Paid')!
    expect(JSON.parse(paid.details as string)).toMatchObject({ from: 'Decision', to: 'Paid', decisionId, amountCents: 420_000 })
    const completed = await auditRows('payout.completed_simulated')
    expect(completed.some((r) => JSON.parse(r.details as string).claimId === id)).toBe(true)

    // the audit trail never contains the reason text (free text stays in the decision record) or the account number
    const dump = JSON.stringify(await auditRows('claim.stage_changed', id)) + JSON.stringify(recorded) + JSON.stringify(completed)
    expect(dump).not.toContain(APPROVE.reason)
    expect(dump).not.toContain(DEMO_PAYOUT.accountNumber)
  })

  it('a decision row is never written without its stage change (stale precondition)', async () => {
    const id = await createReviewedClaim()
    const [a, b] = await Promise.all([
      call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: APPROVE }),
      call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: REJECT }),
    ])
    expect([a.status, b.status].sort()).toEqual([200, 409])
    expect(await decisionRows(id)).toHaveLength(1)
    expect(await auditRows('claim.stage_changed', id)).toHaveLength(5) // Submitted, Verified, Screening, Review, Decision
  })
})
