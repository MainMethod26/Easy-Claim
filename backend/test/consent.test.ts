import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import {
  assessorA,
  auditRows,
  call,
  completeDocuments,
  createSubmittedClaim,
  customerA,
  customerB,
  insurerAdminA,
  insurerAdminB,
  managerA,
  saveProfile,
  sendAndSignLinkConsent,
  signClaimConsent,
  superadmin,
  type TestActor,
} from './helpers'

// POPIA consent / mandate forms (migration 0015): after the insurer checks the documents the customer
// is sent the insurer's own form, signs it (typed name + password), and only then does work continue.
// A declined or withdrawn form stops further work; the text and signature are fixed once written.

async function json(res: Response) {
  return (await res.json()) as Record<string, any>
}

async function verifiedClaim(): Promise<string> {
  const id = await createSubmittedClaim()
  const r = await call(`/claims/${id}/verify`, { method: 'POST', as: assessorA })
  expect(r.status).toBe(200)
  expect((await json(r)).consentRequested).toBe(true)
  return id
}

async function pendingForm(subjectId: string, customer: TestActor = customerA) {
  const list = await json(await call('/consents', { as: customer }))
  return list.consents.find((x: { subjectId: string; status: string }) => x.subjectId === subjectId && x.status === 'pending')
}

const sign = (id: string, body: Record<string, unknown>, as: TestActor = customerA) => call(`/consents/${id}/sign`, { method: 'POST', as, json: body })

describe('claims: consent after the document check', () => {
  it('CON-01 Verify sends the form; Screening waits for the signature; everyone sees the status', async () => {
    const id = await verifiedClaim()
    const blocked = await call(`/claims/${id}/screen`, { method: 'POST', as: assessorA })
    expect(blocked.status).toBe(409)
    expect(await blocked.json()).toEqual({ error: 'consent_required' })
    expect((await auditRows('claim.transition_rejected', id)).some((r) => String(r.details).includes('consent_required'))).toBe(true)

    const form = await pendingForm(id)
    expect(form).toMatchObject({ subjectType: 'claim', status: 'pending', insurerName: 'Discovery Health', templateVersion: 0, signAs: expect.any(String) })
    expect(form.body).toContain('Discovery Health')
    expect(form.body).toContain('POPIA')
    expect(form.body).not.toMatch(/\{\{\w+\}\}/) // every placeholder filled in
    expect(form.bodySha256).toMatch(/^[0-9a-f]{64}$/)
    expect((await json(await call(`/claims/${id}`, { as: assessorA }))).claim.consent).toMatchObject({ status: 'pending', seal: null })
    expect((await json(await call(`/claims/${id}/consent`, { as: managerA }))).consent.body).toBe(form.body)
  })

  it('CON-02 signing needs agreement, the name on record and the password; then Screening opens', async () => {
    const id = await verifiedClaim()
    const form = await pendingForm(id)
    const good = { agree: true, fullName: form.signAs, password: env.DEMO_LOGIN_PASSWORD }
    expect((await sign(form.id, { ...good, agree: false })).status).toBe(400)
    expect((await sign(form.id, { ...good, password: 'wrong-password' })).status).toBe(401)
    const wrongName = await sign(form.id, { ...good, fullName: 'Somebody Else' })
    expect(wrongName.status).toBe(400)
    expect(await wrongName.json()).toEqual({ error: 'name_mismatch' })
    // Not the customer's form → 404; staff cannot sign for the customer → 403.
    expect((await sign(form.id, good, customerB)).status).toBe(404)
    expect((await call(`/consents/${form.id}/sign`, { method: 'POST', as: assessorA, json: good })).status).toBe(403)

    const ok = await sign(form.id, { ...good, fullName: `  ${String(form.signAs).toUpperCase()} ` }) // case and spacing do not matter
    expect(ok.status).toBe(200)
    expect((await json(ok)).consent).toMatchObject({ status: 'signed', seal: 'VALID', signedAt: expect.any(String) })
    expect((await sign(form.id, good)).status).toBe(409) // once only

    expect((await call(`/claims/${id}/screen`, { method: 'POST', as: assessorA })).status).toBe(200)
    const rows = await auditRows('consent.sign', form.id)
    expect(rows.map((r) => r.outcome).sort()).toEqual(['denied', 'denied', 'success'])
    expect(JSON.stringify(rows)).not.toContain('POPIA') // the form text never goes into the audit log
    expect(JSON.stringify(rows)).not.toContain(env.DEMO_LOGIN_PASSWORD)
  })

  it('CON-03 withdrawal stops further work until a new form is signed', async () => {
    const id = await verifiedClaim()
    const signed = await signClaimConsent(id)
    expect((await call(`/claims/${id}/screen`, { method: 'POST', as: assessorA })).status).toBe(200)
    const w = await call(`/consents/${signed.id}/withdraw`, { method: 'POST', as: customerA, json: { reason: 'I want to think about it.' } })
    expect(w.status).toBe(200)
    expect((await json(w)).consent).toMatchObject({ status: 'withdrawn', reason: 'I want to think about it.' })
    const stopped = await call(`/claims/${id}/review`, { method: 'POST', as: assessorA })
    expect(await stopped.json()).toEqual({ error: 'consent_withdrawn' })
    expect((await json(await call(`/claims/${id}`, { as: managerA }))).claim.consent.status).toBe('withdrawn')

    // Staff send a new form; the customer signs; work continues.
    expect((await call(`/claims/${id}/consent`, { method: 'POST', as: assessorA })).status).toBe(201)
    expect((await call(`/claims/${id}/consent`, { method: 'POST', as: assessorA })).status).toBe(409) // one open form at a time
    await signClaimConsent(id)
    expect((await call(`/claims/${id}/review`, { method: 'POST', as: assessorA })).status).toBe(200)
    expect((await auditRows('consent.withdraw', String(signed.id))).length).toBe(1)
  })

  it('CON-04 a declined form keeps the claim waiting; staff or the insurer admin of that insurer can re-send', async () => {
    const id = await verifiedClaim()
    const form = await pendingForm(id)
    expect((await call(`/consents/${form.id}/decline`, { method: 'POST', as: customerA, json: {} })).status).toBe(200)
    expect((await call(`/consents/${form.id}/withdraw`, { method: 'POST', as: customerA, json: {} })).status).toBe(409) // not signed
    expect(await (await call(`/claims/${id}/screen`, { method: 'POST', as: assessorA })).json()).toEqual({ error: 'consent_required' })
    expect((await call(`/claims/${id}/consent`, { method: 'POST', as: customerA })).status).toBe(403)
    expect((await call(`/claims/${id}/consent`, { method: 'POST', as: superadmin })).status).toBe(403)
    expect((await call(`/claims/${id}/consent`, { method: 'POST', as: insurerAdminB })).status).toBe(404)
    expect((await call(`/claims/${id}/consent`, { method: 'GET', as: customerB })).status).toBe(404)
    // The insurer admin sends the mandate (a communication), but still cannot move the claim.
    expect((await call(`/claims/${id}/consent`, { method: 'POST', as: insurerAdminA })).status).toBe(201)
    expect((await call(`/claims/${id}/consent`, { method: 'POST', as: managerA })).status).toBe(409)
    expect((await call(`/claims/${id}/screen`, { method: 'POST', as: insurerAdminA })).status).toBe(403)
  })

  it('CON-05 the text, subject and signature are fixed once written, and forms are never deleted', async () => {
    const id = await verifiedClaim()
    const signed = await signClaimConsent(id)
    const attempts = [
      "UPDATE consents SET body = 'I agree to everything' WHERE id = ?",
      "UPDATE consents SET subject_id = 'claim_other' WHERE id = ?",
      "UPDATE consents SET signed_name = 'Someone Else' WHERE id = ?",
      'DELETE FROM consents WHERE id = ?',
    ]
    for (const sql of attempts) {
      const outcome = await env.DB.prepare(sql).bind(signed.id).run().then(() => 'applied', (e) => String(e))
      expect(outcome, sql).toMatch(/fixed|cannot be changed|cannot be deleted/)
    }
  })

  it('CON-06 repeated wrong passwords lock signing for a while', async () => {
    const id = await verifiedClaim()
    const form = await pendingForm(id)
    // Earlier tests in this file already spent some wrong passwords for this customer (same window).
    const statuses: number[] = []
    for (let i = 0; i < 6 && statuses.at(-1) !== 429; i++) statuses.push((await sign(form.id, { agree: true, fullName: form.signAs, password: `nope-${i}` })).status)
    expect(statuses.at(-1)).toBe(429)
    expect(statuses.filter((s) => s === 401).length).toBeLessThanOrEqual(5)
    const locked = await sign(form.id, { agree: true, fullName: form.signAs, password: env.DEMO_LOGIN_PASSWORD })
    expect(locked.status).toBe(429)
  })
})

describe("the insurer's own wording", () => {
  it('CON-10 starter text until the insurer saves its own; later edits never change forms already sent', async () => {
    const start = await json(await call('/tenant/consent-templates', { as: insurerAdminA }))
    expect(start.claim).toMatchObject({ version: 0, isStarter: true })
    expect(start.placeholders).toContain('{{insurer}}')
    const before = await verifiedClaim()
    const oldText = (await pendingForm(before)).body

    const mine = `{{insurer}} CLAIM CONSENT for {{customer}} ({{easyclaimId}}) about {{subject}}. ${'We process your claim information only to assess and pay it, share it only with our assessors and reinsurers, keep it as the law requires, and you may withdraw consent at any time in the app. '.repeat(2)}`
    expect((await call('/tenant/consent-templates/claim', { method: 'PUT', as: insurerAdminA, json: { body: 'too short' } })).status).toBe(400)
    expect((await call('/tenant/consent-templates/other', { method: 'PUT', as: insurerAdminA, json: { body: mine } })).status).toBe(400)
    expect((await call('/tenant/consent-templates/claim', { method: 'PUT', as: assessorA, json: { body: mine } })).status).toBe(403)
    const saved = await call('/tenant/consent-templates/claim', { method: 'PUT', as: insurerAdminA, json: { body: mine } })
    expect(saved.status).toBe(200)
    expect((await json(saved)).template).toMatchObject({ kind: 'claim', version: 1, isStarter: false })
    // Another insurer still has its own (starter) text.
    expect((await json(await call('/tenant/consent-templates', { as: insurerAdminB }))).claim.version).toBe(0)

    const after = await verifiedClaim()
    const form = await pendingForm(after)
    expect(form.templateVersion).toBe(1)
    expect(form.body.startsWith('Discovery Health CLAIM CONSENT for')).toBe(true)
    expect((await pendingForm(before)).body).toBe(oldText)
    expect((await auditRows('consent.template_saved', 'ins_discovery')).length).toBeGreaterThan(0)
    // Saved versions are append-only.
    await expect(env.DB.prepare("UPDATE consent_templates SET body = 'x' WHERE tenant_id = 'ins_discovery'").run()).rejects.toThrow(/append-only/)
    await expect(env.DB.prepare("DELETE FROM consent_templates WHERE tenant_id = 'ins_discovery'").run()).rejects.toThrow(/append-only/)
  })
})

describe('onboarding: consent before approval', () => {
  it('CON-20 form only after every document is checked; approval needs the signature; withdrawal blocks new claims', async () => {
    expect((await saveProfile(customerB, { legalName: 'Lerato Consent' })).status).toBe(200)
    const req = await json(await call('/covers/link-requests', { method: 'POST', as: customerB, json: { tenantId: 'ins_discovery', policyNumber: 'DH-CONSENT-1' } }))
    const requestId = req.request.id as string
    const early = await call(`/tenant/policy-requests/${requestId}/consent`, { method: 'POST', as: insurerAdminA })
    expect(await early.json()).toEqual({ error: 'documents_incomplete' })
    expect((await call(`/tenant/policy-requests/${requestId}/consent`, { method: 'POST', as: insurerAdminB })).status).toBe(404)

    await completeDocuments(requestId, customerB, insurerAdminA)
    const signed = await sendAndSignLinkConsent(requestId, customerB, insurerAdminA)
    expect(signed).toMatchObject({ subjectType: 'policy_link', status: 'signed', seal: 'VALID', signedName: 'Lerato Consent' })
    expect((await json(await call(`/tenant/policy-requests/${requestId}/consent`, { as: insurerAdminA }))).consent.body).toContain('DH-CONSENT-1')

    const approved = await json(await call(`/tenant/policy-requests/${requestId}/approve`, { method: 'POST', as: insurerAdminA, json: { planName: 'Consent Plan' } }))
    const policyId = approved.request.policyId as string
    expect((await call('/claims/initiate', { method: 'POST', as: customerB, json: { policyId } })).status).toBe(201)

    expect((await call(`/consents/${signed.id}/withdraw`, { method: 'POST', as: customerB, json: {} })).status).toBe(200)
    const refused = await call('/claims/initiate', { method: 'POST', as: customerB, json: { policyId } })
    expect(refused.status).toBe(422)
    expect((await auditRows('claim.initiate_rejected', policyId)).some((r) => String(r.details).includes('consent_withdrawn'))).toBe(true)
  })
})
