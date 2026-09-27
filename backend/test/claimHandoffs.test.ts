import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import {
  VALID_PDF_BYTES,
  assessorA,
  assessorB,
  auditRows,
  call,
  claimStage,
  createReviewedClaim,
  createSubmittedClaim,
  customerA,
  customerB,
  evidenceFile,
  insurerAdminA,
  managerA,
  superadmin,
} from './helpers'

// Claim hand-offs (migration 0013, src/claims/messages.ts): information requests with a message,
// the customer's answer, appeal and withdraw reasons, and the claim conversation.

async function json(res: Response) {
  return (await res.json()) as Record<string, any>
}

async function screeningClaim(): Promise<string> {
  const id = await createSubmittedClaim()
  for (const step of ['verify', 'screen']) {
    const r = await call(`/claims/${id}/${step}`, { method: 'POST', as: assessorA })
    if (r.status !== 200) throw new Error(`${step} ${r.status}`)
  }
  return id
}

describe('information requests', () => {
  it('HO-01 staff say what they need; the customer sees it on the claim; stored with the transition', async () => {
    const id = await screeningClaim()
    const r = await call(`/claims/${id}/request-info`, { method: 'POST', as: assessorA, json: { message: 'Please upload the hospital invoice.' } })
    expect(r.status).toBe(200)
    expect(await claimStage(id)).toMatchObject({ stage: 'Info Needed' })
    const detail = (await json(await call(`/claims/${id}`, { as: customerA }))).claim
    expect(detail.infoRequest).toMatchObject({ body: 'Please upload the hospital invoice.' })
    const msgs = (await json(await call(`/claims/${id}/messages`, { as: customerA }))).messages
    expect(msgs).toEqual([expect.objectContaining({ kind: 'info_request', authorRole: 'ASSESSOR', mine: false })])
    // The free text is never copied into the audit trail.
    const audit = await auditRows('claim.stage_changed', id)
    expect(JSON.stringify(audit)).not.toContain('hospital invoice')
  })

  it('HO-02 older clients may send no body; a malformed body is refused', async () => {
    const id = await screeningClaim()
    expect((await call(`/claims/${id}/request-info`, { method: 'POST', as: assessorA, json: { message: 'x', extra: 1 } })).status).toBe(400)
    expect((await call(`/claims/${id}/request-info`, { method: 'POST', as: assessorA })).status).toBe(200)
    expect((await json(await call(`/claims/${id}`, { as: customerA }))).claim.infoRequest).toBeNull()
  })

  it('HO-03 the customer answers: back to Screening with the reply; only in Info Needed; only the owner', async () => {
    const id = await screeningClaim()
    await call(`/claims/${id}/request-info`, { method: 'POST', as: assessorA, json: { message: 'Need the invoice.' } })
    expect((await call(`/claims/${id}/respond`, { method: 'POST', as: customerB, json: { message: 'Here it is' } })).status).toBe(404)
    expect((await call(`/claims/${id}/respond`, { method: 'POST', as: assessorA, json: { message: 'Here it is' } })).status).toBe(403)
    const fd = new FormData()
    fd.append('file', evidenceFile(VALID_PDF_BYTES, 'invoice.pdf'))
    expect((await call(`/claims/${id}/evidence`, { method: 'POST', as: customerA, formData: fd })).status).toBe(201)
    const r = await call(`/claims/${id}/respond`, { method: 'POST', as: customerA, json: { message: 'Uploaded the hospital invoice.' } })
    expect(r.status).toBe(200)
    expect(await claimStage(id)).toMatchObject({ stage: 'Screening' })
    const msgs = (await json(await call(`/claims/${id}/messages`, { as: assessorA }))).messages
    expect(msgs.map((m: { kind: string }) => m.kind)).toEqual(['info_request', 'customer_reply'])
    expect((await call(`/claims/${id}/respond`, { method: 'POST', as: customerA, json: { message: 'again' } })).status).toBe(409)
  })

  it('HO-04 an evidence upload counts as activity (the Info Needed expiry job reads updated_at)', async () => {
    const id = await screeningClaim()
    await call(`/claims/${id}/request-info`, { method: 'POST', as: assessorA, json: { message: 'Need the invoice.' } })
    await env.DB.prepare("UPDATE claims SET updated_at = '2020-01-01T00:00:00Z' WHERE id = ?").bind(id).run()
    const fd = new FormData()
    fd.append('file', evidenceFile(VALID_PDF_BYTES, 'invoice.pdf'))
    await call(`/claims/${id}/evidence`, { method: 'POST', as: customerA, formData: fd })
    const row = await env.DB.prepare('SELECT updated_at FROM claims WHERE id = ?').bind(id).first<{ updated_at: string }>()
    expect(row!.updated_at > '2026-01-01').toBe(true)
  })
})

describe('appeal and withdraw reasons', () => {
  it('HO-10 the appeal reason is kept and shown to the manager', async () => {
    const id = await createReviewedClaim()
    const d = await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Rejected', reason: 'Outside cover period' } })
    expect(d.status).toBe(200)
    expect((await call(`/claims/${id}/appeal`, { method: 'POST', as: customerA, json: { reason: 'The incident date was mistyped; it was 12 September.' } })).status).toBe(200)
    const detail = (await json(await call(`/claims/${id}`, { as: managerA }))).claim
    expect(detail.stage).toBe('Appeal')
    expect(detail.appealReason).toMatchObject({ body: 'The incident date was mistyped; it was 12 September.' })
  })

  it('HO-11 withdraw with or without a reason; the reason is kept', async () => {
    const a = await createSubmittedClaim()
    expect((await call(`/claims/${a}/withdraw`, { method: 'POST', as: customerA })).status).toBe(200)
    const b = await createSubmittedClaim()
    expect((await call(`/claims/${b}/withdraw`, { method: 'POST', as: customerA, json: { reason: 'Settled privately' } })).status).toBe(200)
    expect(await claimStage(b)).toMatchObject({ stage: 'Withdrawn' })
    expect((await json(await call(`/claims/${b}/messages`, { as: customerA }))).messages[0]).toMatchObject({ kind: 'withdraw', body: 'Settled privately' })
    const c = await createSubmittedClaim()
    expect((await call(`/claims/${c}/withdraw`, { method: 'POST', as: customerA, json: { reason: 'x', other: 1 } })).status).toBe(400)
  })
})

describe('claim conversation', () => {
  it('HO-20 customer and claim staff can post; insurer admin reads only; others cannot see it', async () => {
    const id = await createSubmittedClaim()
    expect((await call(`/claims/${id}/messages`, { method: 'POST', as: customerA, json: { body: 'When will I hear back?' } })).status).toBe(201)
    expect((await call(`/claims/${id}/messages`, { method: 'POST', as: assessorA, json: { body: 'Within two working days.' } })).status).toBe(201)
    expect((await call(`/claims/${id}/messages`, { method: 'POST', as: insurerAdminA, json: { body: 'hi' } })).status).toBe(403)
    expect((await call(`/claims/${id}/messages`, { method: 'POST', as: superadmin, json: { body: 'hi' } })).status).toBe(403)
    expect((await call(`/claims/${id}/messages`, { as: insurerAdminA })).status).toBe(200)
    expect((await call(`/claims/${id}/messages`, { as: assessorB })).status).toBe(404)
    expect((await call(`/claims/${id}/messages`, { as: customerB })).status).toBe(404)
    expect((await call(`/claims/${id}/messages`, { as: superadmin })).status).toBe(404)
    const mine = (await json(await call(`/claims/${id}/messages`, { as: customerA }))).messages
    expect(mine.map((m: { mine: boolean; authorRole: string }) => [m.authorRole, m.mine])).toEqual([
      ['CUSTOMER', true],
      ['ASSESSOR', false],
    ])
    expect(JSON.stringify(mine)).not.toContain('assessor_a1') // other parties' ids are not exposed
    expect((await auditRows('claim.message_posted', id)).length).toBe(2)
  })

  it('HO-21 no messages on drafts; bodies are bounded; a flood is throttled; rows are append-only', async () => {
    const draft = (await json(await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001' } }))).claimId
    expect((await call(`/claims/${draft}/messages`, { method: 'POST', as: customerA, json: { body: 'hello' } })).status).toBe(409)
    const id = await createSubmittedClaim()
    expect((await call(`/claims/${id}/messages`, { method: 'POST', as: customerA, json: { body: 'x'.repeat(2001) } })).status).toBe(400)
    for (let i = 0; i < 20; i++) {
      expect((await call(`/claims/${id}/messages`, { method: 'POST', as: customerA, json: { body: `message ${i}` } })).status).toBe(201)
    }
    expect((await call(`/claims/${id}/messages`, { method: 'POST', as: customerA, json: { body: 'one too many' } })).status).toBe(429)
    await expect(env.DB.prepare("UPDATE claim_messages SET body = 'edited' WHERE claim_id = ?").bind(id).run()).rejects.toThrow()
    await expect(env.DB.prepare('DELETE FROM claim_messages WHERE claim_id = ?').bind(id).run()).rejects.toThrow()
  })
})
