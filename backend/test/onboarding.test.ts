import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import { assessorA, auditRows, call, completeDocuments, customerA, customerB, insurerAdminA, insurerAdminB, managerA, saveProfile, superadmin } from './helpers'

// Insurer onboarding (apply → operator approves) and policy linking (customer requests → insurer approves).
// src/onboarding/service.ts, migration 0011, docs/admin/ROLE_MATRIX.md.

const APP = {
  companyName: 'Hollard Insurance',
  fspNumber: '1234',
  contactEmail: 'Claims@Hollard.example',
  adminUsername: 'admin_hollard',
  adminDisplayName: 'Hollard Admin',
  password: 'hollard-pass-1',
}

async function json(res: Response) {
  return (await res.json()) as Record<string, any>
}

async function apply(overrides: Partial<typeof APP> = {}) {
  return call('/auth/insurer-applications', { method: 'POST', json: { ...APP, ...overrides } })
}

describe('insurer onboarding', () => {
  it('ONB-01 anyone can apply without a token; nothing is created until approval; the password is only hashed', async () => {
    const res = await apply()
    expect(res.status).toBe(201)
    const body = await json(res)
    expect(body.application).toMatchObject({ status: 'pending', companyName: 'Hollard Insurance' })
    expect(JSON.stringify(body)).not.toContain('hollard-pass-1')
    const row = await env.DB.prepare('SELECT * FROM insurer_applications WHERE id = ?').bind(body.application.id).first<Record<string, string>>()
    expect(row!.admin_password_hash).toMatch(/^pbkdf2/)
    expect(row!.contact_email).toBe('claims@hollard.example')
    expect(await env.DB.prepare("SELECT 1 FROM users WHERE username = 'admin_hollard'").first()).toBeNull()
    // Cannot sign in yet.
    expect((await call('/auth/login', { method: 'POST', json: { username: 'admin_hollard', password: 'hollard-pass-1' } })).status).toBe(401)
    expect((await auditRows('onboarding.application_submitted', body.application.id)).length).toBe(1)
  })

  it('ONB-02 duplicates and bad input are refused', async () => {
    expect((await apply()).status).toBe(409) // same username still pending
    expect((await apply({ adminUsername: 'other_admin' })).status).toBe(409) // same FSP number still pending
    expect((await apply({ adminUsername: 'mike', fspNumber: '9999' })).status).toBe(409) // existing account
    expect((await apply({ fspNumber: 'ABC' })).status).toBe(400)
    expect((await apply({ contactEmail: 'not-an-email' })).status).toBe(400)
    expect((await call('/auth/insurer-applications', { method: 'POST', json: { ...APP, role: 'SUPERADMIN' } })).status).toBe(400)
  })

  it('ONB-03 only the platform operator reviews applications', async () => {
    for (const who of [customerA, assessorA, managerA, insurerAdminA]) {
      expect((await call('/admin/applications', { as: who })).status).toBe(403)
    }
    const list = await json(await call('/admin/applications?status=pending', { as: superadmin }))
    expect(list.applications.map((a: { adminUsername: string }) => a.adminUsername)).toContain('admin_hollard')
    expect(JSON.stringify(list)).not.toContain('pbkdf2')
  })

  it('ONB-04 approve creates the insurer and its admin in one step; the new admin signs in to its own tenant', async () => {
    const [app] = (await json(await call('/admin/applications?status=pending', { as: superadmin }))).applications
    expect((await call(`/admin/applications/${app.id}/approve`, { method: 'POST', as: superadmin, json: { tenantId: 'bad id' } })).status).toBe(400)
    expect((await call(`/admin/applications/${app.id}/approve`, { method: 'POST', as: superadmin, json: { tenantId: 'ins_discovery' } })).status).toBe(409)

    const ok = await call(`/admin/applications/${app.id}/approve`, { method: 'POST', as: superadmin, json: { tenantId: 'ins_hollard' } })
    expect(ok.status).toBe(200)
    expect((await json(ok)).application).toMatchObject({ status: 'approved', tenantId: 'ins_hollard' })
    expect(await env.DB.prepare("SELECT name FROM tenants WHERE id = 'ins_hollard'").first()).toEqual({ name: 'Hollard Insurance' })
    const stored = await env.DB.prepare('SELECT admin_password_hash FROM insurer_applications WHERE id = ?').bind(app.id).first<{ admin_password_hash: string }>()
    expect(stored!.admin_password_hash).toBe('') // cleared once decided

    const login = await json(await call('/auth/login', { method: 'POST', json: { username: 'admin_hollard', password: 'hollard-pass-1' } }))
    expect(login.actor).toMatchObject({ role: 'INSURER_ADMIN', tenantId: 'ins_hollard' })
    for (const action of ['onboarding.application_approved', 'admin.tenant_created', 'admin.user_created']) {
      expect((await auditRows(action)).some((r) => r.actor_id === 'usr_superadmin'), action).toBe(true)
    }
    // Deciding twice changes nothing.
    expect((await call(`/admin/applications/${app.id}/approve`, { method: 'POST', as: superadmin, json: { tenantId: 'ins_hollard2' } })).status).toBe(409)
    expect((await call(`/admin/applications/${app.id}/reject`, { method: 'POST', as: superadmin, json: { reason: 'Changed my mind' } })).status).toBe(409)
    expect(await env.DB.prepare("SELECT 1 FROM tenants WHERE id = 'ins_hollard2'").first()).toBeNull()
  })

  it('ONB-05 reject needs a reason, records it, and creates nothing', async () => {
    const created = await json(await apply({ adminUsername: 'admin_fake', fspNumber: '777', companyName: 'Discovery Health (not really)' }))
    const id = created.application.id
    expect((await call(`/admin/applications/${id}/reject`, { method: 'POST', as: superadmin, json: {} })).status).toBe(400)
    const r = await call(`/admin/applications/${id}/reject`, { method: 'POST', as: superadmin, json: { reason: 'FSP number does not match the FSCA register' } })
    expect(r.status).toBe(200)
    expect((await json(r)).application).toMatchObject({ status: 'rejected', decisionReason: 'FSP number does not match the FSCA register', tenantId: null })
    expect(await env.DB.prepare("SELECT 1 FROM users WHERE username = 'admin_fake'").first()).toBeNull()
    expect((await auditRows('onboarding.application_rejected', id)).length).toBe(1)
    // After a rejection the same username may apply again.
    expect((await apply({ adminUsername: 'admin_fake', fspNumber: '778' })).status).toBe(201)
  })

  it('ONB-06 unknown application → 404', async () => {
    expect((await call('/admin/applications/app_nope/approve', { method: 'POST', as: superadmin, json: { tenantId: 'ins_nope' } })).status).toBe(404)
  })
})

describe('policy linking', () => {
  let requestId = ''

  it('LINK-01 a customer lists insurers and asks to link a policy; nothing is created yet', async () => {
    // Details first: without a profile the request is refused.
    expect((await call('/covers/link-requests', { method: 'POST', as: customerB, json: { tenantId: 'ins_discovery', policyNumber: 'dh-778899' } })).status).toBe(409)
    expect((await saveProfile(customerB, { legalName: 'Lerato Nkosi' })).status).toBe(200)
    expect((await saveProfile(customerA, { legalName: 'Mike Test' })).status).toBe(200)
    const insurers = await json(await call('/covers/insurers', { as: customerB }))
    expect(insurers.insurers).toContainEqual({ id: 'ins_discovery', name: 'Discovery Health' })
    expect((await call('/covers/insurers', { as: insurerAdminA })).status).toBe(403)

    const res = await call('/covers/link-requests', { method: 'POST', as: customerB, json: { tenantId: 'ins_discovery', policyNumber: 'dh-778899' } })
    expect(res.status).toBe(201)
    const body = await json(res)
    expect(body.request).toMatchObject({ status: 'pending', policyNumber: 'DH-778899', insurerName: 'Discovery Health' })
    expect(body.request.customer).toBeUndefined()
    requestId = body.request.id
    // Lerato's seeded OUTsurance policy only; nothing new until the insurer approves.
    expect((await json(await call('/covers/my-covers', { as: customerB }))).policies.map((p: { id: string }) => p.id)).toEqual(['pol_out_003'])
    expect((await auditRows('cover.link_requested', requestId)).length).toBe(1)
  })

  it('LINK-02 duplicates, bad input and staff callers are refused', async () => {
    expect((await call('/covers/link-requests', { method: 'POST', as: customerA, json: { tenantId: 'ins_discovery', policyNumber: 'DH-778899' } })).status).toBe(409)
    expect((await call('/covers/link-requests', { method: 'POST', as: customerB, json: { tenantId: 'ins_nowhere', policyNumber: 'X-1234' } })).status).toBe(404)
    expect((await call('/covers/link-requests', { method: 'POST', as: customerB, json: { tenantId: 'ins_discovery', policyNumber: 'a b' } })).status).toBe(400)
    expect((await call('/covers/link-requests', { method: 'POST', as: customerB, json: { tenantId: 'ins_discovery', policyNumber: 'DH-1', userId: 'user123' } })).status).toBe(400)
    expect((await call('/covers/link-requests', { method: 'POST', as: assessorA, json: { tenantId: 'ins_discovery', policyNumber: 'DH-5555' } })).status).toBe(403)
  })

  it('LINK-03 only that insurer\'s admin sees and decides the request', async () => {
    const mine = await json(await call('/tenant/policy-requests?status=pending', { as: insurerAdminA }))
    expect(mine.requests.find((r: { id: string }) => r.id === requestId)).toMatchObject({ customer: { username: 'lerato' }, documentsComplete: false })
    const other = await json(await call('/tenant/policy-requests', { as: insurerAdminB }))
    expect(other.requests.some((r: { id: string }) => r.id === requestId)).toBe(false)
    // Another insurer cannot decide it (404, not 403), and claim staff cannot use the tenant console.
    expect((await call(`/tenant/policy-requests/${requestId}/approve`, { method: 'POST', as: insurerAdminB, json: { planName: 'Stolen' } })).status).toBe(404)
    expect((await call(`/tenant/policy-requests/${requestId}/approve`, { method: 'POST', as: managerA, json: { planName: 'X plan' } })).status).toBe(403)
    expect((await call(`/tenant/policy-requests/${requestId}/approve`, { method: 'POST', as: superadmin, json: { planName: 'X plan' } })).status).toBe(403)
  })

  it('LINK-04 approval creates an Active policy for that customer, who can then start a claim on it', async () => {
    // Not before every required document is uploaded and checked.
    const early = await call(`/tenant/policy-requests/${requestId}/approve`, { method: 'POST', as: insurerAdminA, json: { planName: 'Discovery Classic Saver' } })
    expect(early.status).toBe(409)
    expect(await early.json()).toEqual({ error: 'documents_incomplete' })
    await completeDocuments(requestId, customerB, insurerAdminA)
    const ok = await call(`/tenant/policy-requests/${requestId}/approve`, { method: 'POST', as: insurerAdminA, json: { planName: 'Discovery Classic Saver' } })
    expect(ok.status).toBe(200)
    const approved = (await json(ok)).request
    expect(approved).toMatchObject({ status: 'approved' })
    const covers = (await json(await call('/covers/my-covers', { as: customerB }))).policies
    expect(covers).toHaveLength(2)
    expect(covers).toContainEqual(
      expect.objectContaining({ id: approved.policyId, plan_name: 'Discovery Classic Saver', status: 'Active', tenant_id: 'ins_discovery', policy_number: 'DH-778899' })
    )
    const claim = await call('/claims/initiate', { method: 'POST', as: customerB, json: { policyId: approved.policyId, category: 'Medical' } })
    expect(claim.status).toBe(201)
    expect((await auditRows('policy.link_approved', requestId)).length).toBe(1)
    // Twice → 409; the policy number is now taken for new requests.
    expect((await call(`/tenant/policy-requests/${requestId}/approve`, { method: 'POST', as: insurerAdminA, json: { planName: 'Again' } })).status).toBe(409)
    expect((await call('/covers/link-requests', { method: 'POST', as: customerA, json: { tenantId: 'ins_discovery', policyNumber: 'DH-778899' } })).status).toBe(409)
    // Another customer cannot use this policy (same answer as for a policy that does not exist).
    expect((await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: approved.policyId } })).status).toBe(422)
  })

  it('LINK-05 reject needs a reason and creates no policy; the customer sees the outcome', async () => {
    const req = (await json(await call('/covers/link-requests', { method: 'POST', as: customerB, json: { tenantId: 'ins_discovery', policyNumber: 'DH-000111' } }))).request
    expect((await call(`/tenant/policy-requests/${req.id}/reject`, { method: 'POST', as: insurerAdminA, json: { reason: 'x' } })).status).toBe(400)
    const r = await call(`/tenant/policy-requests/${req.id}/reject`, { method: 'POST', as: insurerAdminA, json: { reason: 'No policy with this number' } })
    expect(r.status).toBe(200)
    const mine = (await json(await call('/covers/link-requests', { as: customerB }))).requests
    expect(mine.find((x: { id: string }) => x.id === req.id)).toMatchObject({ status: 'rejected', decisionReason: 'No policy with this number' })
    expect(await env.DB.prepare("SELECT 1 FROM policies WHERE policy_number = 'DH-000111'").first()).toBeNull()
    // Another customer's requests are not visible.
    expect((await json(await call('/covers/link-requests', { as: customerA }))).requests.some((x: { id: string }) => x.id === req.id)).toBe(false)
  })

  it('LINK-06 the dashboards count pending work', async () => {
    await call('/covers/link-requests', { method: 'POST', as: customerB, json: { tenantId: 'ins_discovery', policyNumber: 'DH-PENDING' } })
    expect((await json(await call('/tenant/overview', { as: insurerAdminA }))).pendingPolicyRequests).toBe(1)
    expect((await json(await call('/admin/overview', { as: superadmin }))).pendingApplications).toBe(1) // admin_fake re-application
  })
})
