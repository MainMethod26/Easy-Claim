import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import {
  VALID_PDF_BYTES,
  VALID_PNG_BYTES,
  assessorA,
  auditRows,
  call,
  customerA,
  customerB,
  evidenceFile,
  insurerAdminA,
  insurerAdminB,
  managerA,
  saIdNumber,
  saveProfile,
  superadmin,
  type TestActor, sendAndSignLinkConsent } from './helpers'

// Customer onboarding with documents (migration 0012, src/onboarding/customerOnboarding.ts).
const ID = saIdNumber('900514')

async function json(res: Response) {
  return (await res.json()) as Record<string, any>
}

async function newRequest(policyNumber: string, as: TestActor = customerA, tenantId = 'ins_discovery') {
  const r = await call('/covers/link-requests', { method: 'POST', as, json: { tenantId, policyNumber } })
  if (r.status !== 201) throw new Error(`${r.status} ${await r.text()}`)
  return (await json(r)).request as { id: string; documents: { key: string; required: boolean; uploaded: boolean }[] }
}

function upload(requestId: string, key: string, as: TestActor = customerA, file = evidenceFile(VALID_PDF_BYTES, `${key}.pdf`)) {
  const fd = new FormData()
  fd.append('file', file)
  return call(`/covers/link-requests/${requestId}/documents/${key}`, { method: 'POST', as, formData: fd })
}

describe('EasyClaim ID and customer details', () => {
  it('CO-01 every customer has an EasyClaim ID; new registrations get one; sign-in returns it', async () => {
    const me = await json(await call('/covers/profile', { as: customerA }))
    expect(me.easyclaimId).toMatch(/^EC-[0-9A-Z]{4}-[0-9A-Z]{4}$/)
    expect(me.profile).toBeNull()
    const reg = await json(await call('/auth/register', { method: 'POST', json: { username: 'nomsa', password: 'nomsa-pass-1', displayName: 'Nomsa Zulu' } }))
    expect(reg.actor.easyclaimId).toMatch(/^EC-[0-9A-Z]{4}-[0-9A-Z]{4}$/)
    expect(reg.actor.easyclaimId).not.toBe(me.easyclaimId)
    // Staff have none.
    expect((await json(await call('/auth/login', { method: 'POST', json: { username: 'admin_discovery', password: env.DEMO_LOGIN_PASSWORD } }))).actor.easyclaimId).toBeNull()
  })

  it('CO-02 details are validated: SA ID checksum and it must match the date of birth', async () => {
    expect((await saveProfile(customerA, { idNumber: '9005145009081' })).status).toBe(400) // bad checksum
    expect((await saveProfile(customerA, { dateOfBirth: '1991-05-14' })).status).toBe(400) // DOB mismatch
    expect((await saveProfile(customerA, { phone: 'call me' })).status).toBe(400)
    expect((await call('/covers/profile', { method: 'PUT', as: customerA, json: { legalName: 'X Y', email: 'x@y.z', phone: '+27825550101', dateOfBirth: '1990-05-14', idNumber: ID, role: 'SUPERADMIN' } })).status).toBe(400)
    expect((await call('/covers/profile', { method: 'PUT', as: insurerAdminA, json: {} })).status).toBe(403)
  })

  it('CO-03 the ID number is encrypted at rest and only ever shown masked to the customer', async () => {
    const saved = await json(await saveProfile(customerA, { legalName: 'Mike Mokoena' }))
    expect(saved.profile).toMatchObject({ legalName: 'Mike Mokoena', idNumberMasked: expect.stringMatching(/•+\d{4}$/) })
    expect(JSON.stringify(saved)).not.toContain(ID)
    const row = await env.DB.prepare('SELECT * FROM customer_profiles WHERE user_id = ?').bind('user123').first<Record<string, string>>()
    expect(JSON.stringify(row)).not.toContain(ID)
    expect(row!.id_number_last4).toBe(ID.slice(-4))
    expect((await auditRows('customer.profile_saved', 'user123')).length).toBeGreaterThan(0)
    expect(JSON.stringify(await auditRows('customer.profile_saved', 'user123'))).not.toContain(ID)
  })

  it('CO-04 without the PII key nothing is stored (fail closed)', async () => {
    const r = await call('/covers/profile', {
      method: 'PUT',
      as: customerB,
      env: { PII_KEY: undefined },
      json: { legalName: 'Lerato Nkosi', email: 'l@example.com', phone: '+27825550101', dateOfBirth: '1990-05-14', idNumber: ID },
    })
    expect(r.status).toBe(503)
    expect(await env.DB.prepare("SELECT 1 FROM customer_profiles WHERE user_id = 'user456'").first()).toBeNull()
  })
})

describe('documents and the insurer decision', () => {
  let reqId = ''

  it('CO-10 a request carries the insurer\'s required-document checklist', async () => {
    const req = await newRequest('DH-1001')
    reqId = req.id
    expect(req.documents.map((d) => d.key)).toEqual(['id_document', 'proof_of_address', 'policy_schedule'])
    expect(req.documents.every((d) => d.required && !d.uploaded)).toBe(true)
    const pub = await json(await call('/covers/insurers/ins_discovery/requirements', { as: customerA }))
    expect(pub.requirements).toHaveLength(3)
  })

  it('CO-11 upload rules: allowed types only, real magic bytes, own open request, known document key', async () => {
    expect((await upload(reqId, 'id_document')).status).toBe(201)
    expect((await upload(reqId, 'proof_of_address', customerA, evidenceFile(VALID_PNG_BYTES, 'bill.png', 'image/png'))).status).toBe(201)
    expect((await upload(reqId, 'policy_schedule', customerA, evidenceFile(VALID_PDF_BYTES, 'x.pdf', 'image/png'))).status).toBe(415) // relabelled
    expect((await upload(reqId, 'policy_schedule', customerA, evidenceFile(new Uint8Array([1, 2, 3]), 'x.exe', 'application/x-msdownload'))).status).toBe(415)
    expect((await upload(reqId, 'selfie')).status).toBe(404)
    expect((await upload(reqId, 'id_document', customerB)).status).toBe(404) // someone else's request
    const stored = await env.DB.prepare('SELECT storage_key FROM request_documents WHERE request_id = ? AND doc_key = ?').bind(reqId, 'id_document').first<{ storage_key: string }>()
    expect(stored!.storage_key).toBe(`onboarding/ins_discovery/${reqId}/id_document`)
    expect((await auditRows('onboarding.document_rejected', reqId)).length).toBeGreaterThanOrEqual(2)
  })

  it('CO-12 the insurer admin sees the client (ID masked), opens documents (audited) and reveals the ID (audited)', async () => {
    const d = (await json(await call(`/tenant/policy-requests/${reqId}`, { as: insurerAdminA }))).request
    expect(d.client).toMatchObject({ displayName: 'Mike', username: 'mike', easyclaimId: expect.stringMatching(/^EC-/), profile: { legalName: 'Mike Mokoena' } })
    expect(JSON.stringify(d)).not.toContain(ID)
    expect(d.readyToApprove).toBe(false)
    const file = await call(`/tenant/policy-requests/${reqId}/documents/id_document`, { as: insurerAdminA })
    expect(file.status).toBe(200)
    expect(file.headers.get('cache-control')).toBe('no-store')
    expect(new Uint8Array(await file.arrayBuffer()).slice(0, 5)).toEqual(VALID_PDF_BYTES.slice(0, 5))
    expect((await auditRows('onboarding.document_accessed', reqId)).length).toBe(1)
    const reveal = await json(await call(`/tenant/policy-requests/${reqId}/reveal-id`, { method: 'POST', as: insurerAdminA }))
    expect(reveal.idNumber).toBe(ID)
    expect((await auditRows('onboarding.id_number_revealed', reqId))[0]).toMatchObject({ actor_id: 'usr_admin_discovery' })
  })

  it('CO-13 nobody else gets in: other insurer 404, claim staff and superadmin 403, customer 403', async () => {
    for (const path of [`/tenant/policy-requests/${reqId}`, `/tenant/policy-requests/${reqId}/documents/id_document`]) {
      expect((await call(path, { as: insurerAdminB })).status).toBe(404)
      expect((await call(path, { as: managerA })).status).toBe(403)
      expect((await call(path, { as: assessorA })).status).toBe(403)
      expect((await call(path, { as: superadmin })).status).toBe(403)
      expect((await call(path, { as: customerA })).status).toBe(403)
    }
    expect((await call(`/tenant/policy-requests/${reqId}/reveal-id`, { method: 'POST', as: insurerAdminB })).status).toBe(404)
  })

  it('CO-14 more-info loop: insurer asks, customer uploads and resubmits, insurer checks each document, then approves', async () => {
    const ask = await call(`/tenant/policy-requests/${reqId}/request-info`, { method: 'POST', as: insurerAdminA, json: { message: 'Please upload your policy schedule.' } })
    expect(ask.status).toBe(200)
    const mine = (await json(await call('/covers/link-requests', { as: customerA }))).requests.find((r: { id: string }) => r.id === reqId)
    expect(mine).toMatchObject({ status: 'more_info', infoMessage: 'Please upload your policy schedule.' })
    // While it is with the customer the insurer cannot approve or tick documents.
    expect((await call(`/tenant/policy-requests/${reqId}/approve`, { method: 'POST', as: insurerAdminA, json: { planName: 'Classic' } })).status).toBe(409)
    expect((await call(`/tenant/policy-requests/${reqId}/documents/id_document/verify`, { method: 'POST', as: insurerAdminA, json: { verified: true } })).status).toBe(409)
    expect((await upload(reqId, 'policy_schedule')).status).toBe(201)
    expect((await call(`/covers/link-requests/${reqId}/resubmit`, { method: 'POST', as: customerA })).status).toBe(200)
    expect((await call(`/covers/link-requests/${reqId}/resubmit`, { method: 'POST', as: customerA })).status).toBe(409)
    for (const key of ['id_document', 'proof_of_address']) {
      expect((await call(`/tenant/policy-requests/${reqId}/documents/${key}/verify`, { method: 'POST', as: insurerAdminA, json: { verified: true } })).status).toBe(200)
    }
    const blocked = await call(`/tenant/policy-requests/${reqId}/approve`, { method: 'POST', as: insurerAdminA, json: { planName: 'Classic' } })
    expect(await blocked.json()).toEqual({ error: 'documents_incomplete' })
    expect((await call(`/tenant/policy-requests/${reqId}/documents/policy_schedule/verify`, { method: 'POST', as: insurerAdminA, json: { verified: true } })).status).toBe(200)
    // Every document checked → the consent form can be sent; approval waits for the signature.
    const checked = (await json(await call(`/tenant/policy-requests/${reqId}`, { as: insurerAdminA }))).request
    expect(checked).toMatchObject({ readyForConsent: true, readyToApprove: false, consent: null })
    await sendAndSignLinkConsent(reqId, customerA, insurerAdminA)
    expect((await json(await call(`/tenant/policy-requests/${reqId}`, { as: insurerAdminA }))).request).toMatchObject({
      readyForConsent: false,
      readyToApprove: true,
      consent: { status: 'signed', seal: 'VALID' },
    })
    // Re-uploading a checked document un-checks it: the insurer must look again.
    expect((await upload(reqId, 'policy_schedule')).status).toBe(201)
    expect((await json(await call(`/tenant/policy-requests/${reqId}`, { as: insurerAdminA }))).request.readyToApprove).toBe(false)
    await call(`/tenant/policy-requests/${reqId}/documents/policy_schedule/verify`, { method: 'POST', as: insurerAdminA, json: { verified: true } })
    const ok = await call(`/tenant/policy-requests/${reqId}/approve`, { method: 'POST', as: insurerAdminA, json: { planName: 'Discovery Classic' } })
    expect(ok.status).toBe(200)
    expect((await json(ok)).request).toMatchObject({ status: 'approved', documentsComplete: true })
    // Closed: no more uploads.
    expect((await upload(reqId, 'id_document')).status).toBe(409)
    for (const a of ['policy.link_more_info', 'cover.link_resubmitted', 'onboarding.document_verified', 'policy.link_approved']) {
      expect((await auditRows(a, reqId)).length, a).toBeGreaterThan(0)
    }
  })
})

describe('insurer settings and customer search', () => {
  it('CO-20 each insurer sets its own required documents; only its admin can', async () => {
    const put = await call('/tenant/requirements', {
      method: 'PUT',
      as: insurerAdminB,
      json: { items: [{ key: 'id_document', label: 'ID document', required: true }, { key: 'bank_letter', label: 'Bank confirmation letter', required: false }] },
    })
    expect(put.status).toBe(200)
    expect((await json(await call('/covers/insurers/ins_sanlam/requirements', { as: customerA }))).requirements).toEqual([
      { key: 'id_document', label: 'ID document', required: true },
      { key: 'bank_letter', label: 'Bank confirmation letter', required: false },
    ])
    // Discovery is unaffected.
    expect((await json(await call('/tenant/requirements', { as: insurerAdminA }))).requirements).toHaveLength(3)
    expect((await call('/tenant/requirements', { method: 'PUT', as: managerA, json: { items: [] } })).status).toBe(403)
    expect((await call('/tenant/requirements', { method: 'PUT', as: insurerAdminB, json: { items: [{ key: 'Bad Key', label: 'x y', required: true }] } })).status).toBe(400)
    expect((await auditRows('tenant.requirements_changed', 'ins_sanlam')).length).toBe(1)
    // A Sanlam request now needs only the ID document.
    const req = await newRequest('SL-2002', customerA, 'ins_sanlam')
    expect(req.documents.filter((d) => d.required).map((d) => d.key)).toEqual(['id_document'])
  })

  it('CO-21 search by EasyClaim ID: exact match; details only for this insurer\'s own clients; audited', async () => {
    const eid = (await json(await call('/covers/profile', { as: customerA }))).easyclaimId as string
    const disc = await json(await call(`/tenant/customers?easyclaimId=${eid.toLowerCase()}`, { as: insurerAdminA }))
    expect(disc.customer).toMatchObject({ easyclaimId: eid, displayName: 'Mike', related: true, client: { username: 'mike' } })
    expect(disc.customer.policies.some((p: { planName: string }) => p.planName === 'Discovery Classic')).toBe(true)
    // An insurer with no relationship learns only the name behind the ID.
    await env.DB.prepare("DELETE FROM policy_link_requests WHERE tenant_id = 'ins_sanlam' AND user_id = 'user123'").run().catch(() => undefined)
    const other = await json(await call(`/tenant/customers?easyclaimId=${eid}`, { as: insurerAdminB }))
    expect(other.customer.displayName).toBe('Mike')
    expect(other.customer.related === false ? other.customer.client : null).toBeNull()
    expect((await call('/tenant/customers?easyclaimId=EC-0000-0000', { as: insurerAdminA })).status).toBe(404)
    expect((await call('/tenant/customers?easyclaimId=mike', { as: insurerAdminA })).status).toBe(400)
    expect((await call(`/tenant/customers?easyclaimId=${eid}`, { as: managerA })).status).toBe(403)
    expect((await auditRows('tenant.customer_lookup', 'ins_discovery')).length).toBeGreaterThanOrEqual(2)
  })
})
